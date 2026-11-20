# Footnote

Every step, noted. A simple Android step counter built with Flutter. Steps are
recorded in the background by a native foreground service using the hardware
step counter, and shown in the app (today + history), in a permanent
notification and in two home screen widgets that adapt their layout to the size
they're given.

The app is in English and Nepali (नेपाली). It follows the phone's language, or
the language picked in the app, which also applies to the widgets and the
notification.

## Translations

App strings live in `lib/l10n/app_<language>.arb`; the Dart classes are
generated from them by `flutter pub get` (see `l10n.yaml`). The widgets and the
notification use Android string resources in
`android/app/src/main/res/values*/strings.xml`. To add a language, add both,
then list it in `AppLocale.supported` (`Metrics.kt`) and in the language
choices (`lib/settings_sheets.dart`, `lib/onboarding.dart`).

## Run locally

```sh
flutter run
```

## Releasing

Releases are built by GitHub Actions (`.github/workflows/release.yml`) and
published as GitHub releases. Each has an APK per CPU architecture, plus a
universal one for anyone who isn't sure which to pick:

| File | For |
| --- | --- |
| `footnote-<version>-arm64-v8a.apk` | most phones (about 8 MB) |
| `footnote-<version>-armeabi-v7a.apk` | older 32-bit phones |
| `footnote-<version>-x86_64.apk` | emulators and x86 devices |
| `footnote-<version>-universal.apk` | any device (about 24 MB) |

All the APKs of a release share one version code, `major × 1000000 + minor ×
1000 + patch` (1.2.0 is 1002000), so any of them can update any other. Versions
must only go up: Android won't install a lower one over a higher one.

### In-app updates

Each release also has an `update.json` listing its APKs with their size and
SHA-256 (written by `.github/scripts/release.py`). When the app opens, it reads
the latest one from `github.com/<repo>/releases/latest/download/update.json`, a
plain download, so the GitHub API's rate limit doesn't apply. If there's a newer
version, it offers it, at most once a day for the same version. **Update**
downloads the APK for the phone's CPU, checks its SHA-256 and opens Android's
installer. The first time, Android asks to allow Footnote to install apps. The
ⓘ button on the Today page shows the version and checks on request.

Only release builds look for updates (the workflow passes `GITHUB_REPO`), not
local ones like `flutter run`.

### One-time setup: signing key

Every release must be signed with the same key, otherwise Android won't install
an update over the existing app. Keep the keystore and its password safe, with a
backup: if you lose them, everyone has to uninstall the app, and lose their step
history, to get later versions.

Use a keystore you already have, or create one:

```sh
keytool -genkeypair -v -keystore ~/footnote-upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Footnote"
```

Then add its repository secrets on GitHub (Settings → Secrets and variables →
Actions → New repository secret):

- `KEYSTORE_BASE64`, the keystore as text: `base64 -w0 path/to/keystore.jks | wl-copy`
  copies it.
- `KEYSTORE_PASSWORD`, its password.
- `KEY_ALIAS`, only if the key's alias isn't `upload`.
  `keytool -list -keystore path/to/keystore.jks` shows it.
- `KEY_PASSWORD`, only if the key has a password of its own, which some old JKS
  keystores do. In PKCS12 ones (keytool's default) it's the keystore password.

Or with the GitHub CLI:

```sh
base64 -w0 path/to/keystore.jks | gh secret set KEYSTORE_BASE64
gh secret set KEYSTORE_PASSWORD
gh secret set KEY_ALIAS # if not "upload"
```

To build signed release APKs locally, create `android/key.properties`
(gitignored):

```properties
storeFile=/absolute/path/to/keystore.jks
storePassword=...
keyAlias=...
```

Release builds are then signed with the release key, so they can't install over
a debug build on your phone (different key), and `flutter run --release`
uninstalls the app first when that happens, deleting its step history. Debug
builds are unaffected.

### Publishing a version

```sh
git tag v1.1.0
git push origin v1.1.0
```

Or on GitHub: Actions → Release → Run workflow, and type the version.

The release notes, also shown in the app's update dialog, are the notes typed
when running the workflow on GitHub, or else the message of an annotated tag
(`git tag -a v1.1.0 -m "Faster charts"`), or else the commit messages since the
last release.

A version with a suffix, like `v1.1.0-beta.1`, becomes a pre-release, which the
app doesn't offer as an update. It's a way to try the workflow or a build first.

### Trying the update flow without a release

`--dart-define=UPDATE_MANIFEST_URL=...` makes a build read `update.json` from
elsewhere, like a server on your computer. With the phone connected over adb:

```sh
# 1. Install a build that checks your computer for updates.
flutter build apk --debug --dart-define=UPDATE_MANIFEST_URL=http://127.0.0.1:8000/update.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 2. Build a "newer" version and describe it in an update.json.
flutter build apk --debug --build-name=9.0.0 --build-number=9000000
mkdir -p /tmp/update && cp build/app/outputs/flutter-apk/app-debug.apk /tmp/update/new.apk && cd /tmp/update
python3 - <<'EOF'
import hashlib, json, os
json.dump({'version': '9.0.0', 'versionCode': 9000000, 'notes': 'Test update', 'releaseUrl': '',
           'apks': [{'abi': 'universal', 'name': 'new.apk', 'url': 'http://127.0.0.1:8000/new.apk',
                     'size': os.path.getsize('new.apk'),
                     'sha256': hashlib.sha256(open('new.apk', 'rb').read()).hexdigest()}]},
          open('update.json', 'w'))
EOF

# 3. Serve it, let the phone reach it, then open the app: ⓘ → Check for updates.
adb reverse tcp:8000 tcp:8000
python3 -m http.server 8000
```

Afterwards, `adb install -r -d` puts a normal debug build back (`-d` allows its
lower version code).
