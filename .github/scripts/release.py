#!/usr/bin/env python3
"""Helpers for .github/workflows/release.yml.

  release.py version 1.2.0 [--latest v1.1.0]
      Checks the version and prints tag=, version=, code= and prerelease= lines
      for $GITHUB_OUTPUT. With --latest, the version must come after that release.

  release.py notes --tag v1.2.0 [--notes TEXT]
      Prints the "What's new" text: TEXT if given, else the tag's annotation, else
      the commit messages since the previous release.

  release.py package --apks DIR --out DIR --body FILE --notes FILE --version 1.2.0
                     --code 1002000 --tag v1.2.0 --repo owner/repo [--cert SHA256]
      Copies the APKs into the release folder under their published names, and writes
      update.json (read by the app, lib/update_checker.dart), SHA256SUMS.txt and the
      release description.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

# A semantic version without build metadata, like 1.2.0 or 1.2.0-beta.1. "v" is optional.
VERSION_RE = re.compile(
    r"^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)

# Each APK the workflow builds, by CPU architecture, and who it's for.
APKS = {
    "arm64-v8a": "Most phones (64-bit ARM)",
    "armeabi-v7a": "Older phones (32-bit ARM)",
    "x86_64": "Emulators, Chromebooks and other x86 devices",
    "universal": "Any device (all of the above in one, bigger download)",
}

MAX_COMMITS_IN_NOTES = 20


class ReleaseError(Exception):
    pass


def parse_version(raw: str) -> tuple[str, int, tuple]:
    """Returns the version name, its version code and a key that sorts versions."""
    match = VERSION_RE.match(raw.strip())
    if not match:
        raise ReleaseError(f'"{raw}" is not a version like 1.2.0 (or 1.2.0-beta.1 for a pre-release).')
    major, minor, patch = (int(part) for part in match.group(1, 2, 3))
    if major > 2099 or minor > 999 or patch > 999:
        raise ReleaseError(f"{raw}: versions go up to 2099.999.999, to fit Android's version code.")
    pre = match.group(4)
    name = f"{major}.{minor}.{patch}" + (f"-{pre}" if pre else "")
    # Shared by every APK of the release (android/gradle.properties) and must only grow.
    # A pre-release has the same code as its release, so the release can replace it.
    code = major * 1_000_000 + minor * 1_000 + patch
    # Semantic versioning order: a pre-release comes before its release, numeric parts
    # compare as numbers and come before text.
    if pre is None:
        pre_key: tuple = ((1,),)
    else:
        pre_key = ((0,) + tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split(".")),)
    return name, code, (major, minor, patch) + pre_key


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def previous_release_tag(tag: str) -> str | None:
    """The latest release tag before [tag] in the history, pre-releases excluded."""
    try:
        return git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*",
                   "--exclude", tag, "--exclude", "*-*", "HEAD")
    except subprocess.CalledProcessError:
        return None


def tag_message(tag: str) -> str:
    """The annotation of [tag], or "" for a lightweight or missing tag."""
    try:
        if git("cat-file", "-t", f"refs/tags/{tag}") != "tag":
            return ""
    except subprocess.CalledProcessError:
        return ""  # Not tagged yet: a manual run creates the tag when publishing.
    subject = git("tag", "-l", "--format=%(contents:subject)", tag)
    body = git("tag", "-l", "--format=%(contents:body)", tag)
    message = f"{subject}\n\n{body}".strip()
    # "v1.2.0" or "Release 1.2.0" says nothing new.
    if re.fullmatch(rf"(?i)(release\s+)?v?{re.escape(tag.removeprefix('v'))}", message):
        return ""
    return message


def release_notes(tag: str, given: str) -> str:
    if given.strip():
        return given.strip()
    message = tag_message(tag)
    if message:
        return message
    previous = previous_release_tag(tag)
    if previous is None:
        return "First release."
    subjects = git("log", "--no-merges", "--format=%s", f"{previous}..HEAD").splitlines()
    if not subjects:
        return "Small fixes and improvements."
    lines = [f"- {subject}" for subject in subjects[:MAX_COMMITS_IN_NOTES]]
    if len(subjects) > MAX_COMMITS_IN_NOTES:
        lines.append(f"- …and {len(subjects) - MAX_COMMITS_IN_NOTES} more")
    return "\n".join(lines)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def megabytes(size: int) -> str:
    return f"{size / 1_000_000:.1f} MB"


def package(args: argparse.Namespace) -> None:
    name, code, _ = parse_version(args.version)
    if name != args.version or code != args.code or args.tag != f"v{name}":
        raise ReleaseError(f"Version {args.version}, code {args.code} and tag {args.tag} don't match.")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    downloads = f"https://github.com/{args.repo}/releases/download/{args.tag}"
    apks = []
    for abi in APKS:
        source = Path(args.apks) / f"app-{abi}-release.apk"
        if not source.is_file():
            raise ReleaseError(f"{source} is missing.")
        file_name = f"footnote-{name}-{abi}.apk"
        target = out / file_name
        shutil.copyfile(source, target)
        apks.append({
            "abi": abi,
            "name": file_name,
            "url": f"{downloads}/{file_name}",
            "size": target.stat().st_size,
            "sha256": sha256(target),
        })

    notes = Path(args.notes).read_text(encoding="utf-8").strip()
    manifest = {
        "version": name,
        "versionCode": code,
        "tag": args.tag,
        "releaseUrl": f"https://github.com/{args.repo}/releases/tag/{args.tag}",
        "notes": notes,
        "apks": apks,
    }
    (out / "update.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (out / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['name']}\n" for a in apks), encoding="utf-8")

    by_abi = {a["abi"]: a for a in apks}
    body = [
        notes,
        "",
        "### Download",
        "",
        f"Most phones need **{by_abi['arm64-v8a']['name']}**. Not sure? "
        f"**{by_abi['universal']['name']}** works on any device.",
        "",
        "| File | For | Size |",
        "| --- | --- | --- |",
        *(f"| [{a['name']}]({a['url']}) | {APKS[a['abi']]} | {megabytes(a['size'])} |" for a in apks),
        "",
        "This is a pre-release: the app doesn't offer it as an update."
        if "-" in name
        else "Already have Footnote? It offers this update the next time you open it.",
    ]
    if args.cert:
        cert = ":".join(args.cert[i:i + 2] for i in range(0, len(args.cert), 2)).upper()
        body += ["", f"<sub>Signing certificate SHA-256: `{cert}`</sub>"]
    previous = previous_release_tag(args.tag)
    if previous:
        body += ["", f"**Full changelog**: https://github.com/{args.repo}/compare/{previous}...{args.tag}"]
    Path(args.body).write_text("\n".join(body) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    version = commands.add_parser("version")
    version.add_argument("version")
    version.add_argument("--latest", help="tag of the latest published release")

    notes = commands.add_parser("notes")
    notes.add_argument("--tag", required=True)
    notes.add_argument("--notes", default="")

    pack = commands.add_parser("package")
    pack.add_argument("--apks", required=True, help="folder with app-<abi>-release.apk files")
    pack.add_argument("--out", required=True)
    pack.add_argument("--body", required=True)
    pack.add_argument("--notes", required=True)
    pack.add_argument("--version", required=True)
    pack.add_argument("--code", required=True, type=int)
    pack.add_argument("--tag", required=True)
    pack.add_argument("--repo", required=True)
    pack.add_argument("--cert", default="", help="SHA-256 of the signing certificate")

    args = parser.parse_args()
    try:
        if args.command == "version":
            name, code, key = parse_version(args.version)
            if args.latest:
                try:
                    latest_name, _, latest_key = parse_version(args.latest)
                except ReleaseError:
                    print(f"Latest release {args.latest} isn't a version; not comparing.", file=sys.stderr)
                else:
                    if key <= latest_key:
                        raise ReleaseError(
                            f"{name} doesn't come after the latest release, {latest_name}. "
                            "Release a higher version: Android won't install a lower one over it."
                        )
            prerelease = "-" in name
            print(f"Releasing {name} (version code {code}){' as a pre-release' if prerelease else ''}.",
                  file=sys.stderr)
            print(f"tag=v{name}\nversion={name}\ncode={code}\nprerelease={str(prerelease).lower()}")
        elif args.command == "notes":
            print(release_notes(args.tag, args.notes))
        else:
            package(args)
    except ReleaseError as e:
        # stderr: stdout may be going to $GITHUB_OUTPUT or a file. Actions reads both.
        print(f"::error::{e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
