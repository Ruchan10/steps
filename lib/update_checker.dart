import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'step_service.dart';

// Updates come from the repository's GitHub releases. Each release made by
// .github/workflows/release.yml has an update.json listing its APKs (see
// .github/scripts/release.py), which the app reads to offer the update.

/// One APK of a release, as listed in its update.json.
class UpdateApk {
  const UpdateApk({
    required this.abi,
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });

  factory UpdateApk.fromJson(Map<String, dynamic> json) => UpdateApk(
        abi: json['abi'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        size: (json['size'] as num).toInt(),
        sha256: json['sha256'] as String,
      );

  /// "arm64-v8a", "armeabi-v7a", "x86_64", or "universal" (any CPU).
  final String abi;

  /// File name, e.g. "footnote-1.2.0-arm64-v8a.apk".
  final String name;
  final String url;

  /// In bytes.
  final int size;

  /// Lowercase hex.
  final String sha256;
}

/// A release newer than the installed app.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.currentVersion,
    required this.notes,
    required this.releaseUrl,
    this.apk,
    this.askToInstall = false,
  });

  final String version;
  final String currentVersion;

  /// What's new; may be empty.
  final String notes;

  /// The release's GitHub page, for when there's no APK for this phone.
  final String releaseUrl;

  /// The APK for this phone's CPU, or null if the release has none.
  final UpdateApk? apk;

  /// Android will ask the user to allow "Install unknown apps" for Footnote first.
  final bool askToInstall;
}

class UpdateChecker {
  /// "owner/repo", set by the release workflow. Empty in local builds, which turns updates off.
  static const repo = String.fromEnvironment('GITHUB_REPO');

  /// Reads update.json from here instead, to try the update flow with a local server.
  static const _manifestOverride = String.fromEnvironment('UPDATE_MANIFEST_URL');

  static bool get enabled => repo.isNotEmpty || _manifestOverride.isNotEmpty;

  /// update.json of the latest release (pre-releases excluded). This link redirects to the
  /// file itself, so unlike the GitHub API it has no 60 requests per hour limit.
  static Uri get manifestUrl => Uri.parse(
        _manifestOverride.isNotEmpty
            ? _manifestOverride
            : 'https://github.com/$repo/releases/latest/download/update.json',
      );

  /// The newer release, or null if up to date (or updates are off, or nothing is released yet).
  /// Throws if it can't tell: offline, GitHub unreachable, broken update.json...
  static Future<AppUpdate?> check() async {
    if (!enabled) return null;
    final info = await StepService.getAppInfo();
    final manifest = await fetchManifest(manifestUrl);
    return manifest == null ? null : updateFromManifest(manifest, info);
  }
}

/// Reads update.json at [url], following redirects. Null if there's none, e.g. no release yet.
Future<Map<String, dynamic>?> fetchManifest(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.userAgentHeader, 'Footnote');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

/// The update described by [manifest], or null if it's not newer than the installed app.
AppUpdate? updateFromManifest(Map<String, dynamic> manifest, AppInfo installed) {
  final version = manifest['version'] as String;
  if (!isNewerVersion(version, installed.version)) return null;
  // Android won't install a lower version code over a higher one.
  final versionCode = (manifest['versionCode'] as num?)?.toInt();
  if (versionCode != null && versionCode < installed.versionCode) return null;

  final apks = [
    for (final apk in manifest['apks'] as List? ?? const []) UpdateApk.fromJson((apk as Map).cast<String, dynamic>()),
  ];
  return AppUpdate(
    version: version,
    currentVersion: installed.version,
    notes: (manifest['notes'] as String? ?? '').trim(),
    releaseUrl: manifest['releaseUrl'] as String? ?? 'https://github.com/${UpdateChecker.repo}/releases/latest',
    apk: apkForAbis(apks, installed.abis),
    askToInstall: !installed.canInstallUpdates,
  );
}

/// The APK for the most preferred of the phone's [abis], else the universal one.
UpdateApk? apkForAbis(List<UpdateApk> apks, List<String> abis) {
  for (final abi in [...abis, 'universal']) {
    for (final apk in apks) {
      if (apk.abi == abi) return apk;
    }
  }
  return null;
}

/// Whether [candidate] is a later version than [current]: "1.10.0" > "1.9.2", and a
/// release comes after its pre-releases, "1.2.0" > "1.2.0-beta.1". Ignores a leading "v"
/// and "+build" suffixes.
bool isNewerVersion(String candidate, String current) => compareVersions(candidate, current) > 0;

/// Orders versions like semantic versioning does.
int compareVersions(String a, String b) {
  final (coreA, preA) = _parseVersion(a);
  final (coreB, preB) = _parseVersion(b);
  for (var i = 0; i < 3; i++) {
    final x = i < coreA.length ? coreA[i] : 0;
    final y = i < coreB.length ? coreB[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  if (preA.isEmpty || preB.isEmpty) return preB.length.compareTo(preA.length).sign;
  for (var i = 0; i < preA.length && i < preB.length; i++) {
    final x = int.tryParse(preA[i]);
    final y = int.tryParse(preB[i]);
    final order = x != null && y != null
        ? x.compareTo(y)
        : x != null
            ? -1 // Numbers come before words: beta.2 < beta.rc
            : y != null
                ? 1
                : preA[i].compareTo(preB[i]);
    if (order != 0) return order.sign;
  }
  return preA.length.compareTo(preB.length).sign;
}

/// "v1.2.0-beta.1+5" -> ([1, 2, 0], ["beta", "1"])
(List<int>, List<String>) _parseVersion(String version) {
  var v = version.trim();
  if (v.startsWith('v')) v = v.substring(1);
  v = v.split('+').first;
  final dash = v.indexOf('-');
  final core = dash < 0 ? v : v.substring(0, dash);
  final pre = dash < 0 ? const <String>[] : v.substring(dash + 1).split('.');
  return (core.split('.').map((p) => int.tryParse(p) ?? 0).toList(), pre);
}

/// Whether to offer [version] when the app opens: always for a version the user hasn't seen,
/// otherwise once [interval] has passed since they were last offered it.
bool isPromptDue(
  String version, {
  required String? lastVersion,
  required DateTime? lastAt,
  required DateTime now,
  Duration interval = const Duration(days: 1),
}) =>
    version != lastVersion || lastAt == null || now.difference(lastAt) >= interval;

/// Downloads one update APK into [dir]. Single use: make a new one to try again.
class ApkDownload {
  ApkDownload(this.apk, this.dir);

  final UpdateApk apk;
  final Directory dir;

  HttpClient? _client;
  var _cancelled = false;

  /// Where the finished download is.
  File get file => File('${dir.path}${Platform.pathSeparator}${apk.name}');

  bool get cancelled => _cancelled;

  /// Downloads the APK, calling [onProgress] with the bytes received so far and the total.
  /// Older downloads in [dir] are deleted first. Throws if the download fails or is cancelled.
  Future<File> start({void Function(int received, int total)? onProgress}) async {
    if (_cancelled) throw const HttpException('Cancelled');
    await deleteOtherDownloads(dir, keep: apk.name);
    final part = File('${file.path}.part');
    final client = _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(apk.url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Footnote');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(apk.url));
      }
      final total = response.contentLength > 0 ? response.contentLength : apk.size;
      final sink = part.openWrite();
      var received = 0;
      try {
        // Gives up if the connection stalls, rather than waiting forever.
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      if (_cancelled) throw const HttpException('Cancelled');
      return await part.rename(file.path);
    } catch (_) {
      await _tryDelete(part);
      rethrow;
    } finally {
      client.close(force: true);
      _client = null;
    }
  }

  /// Stops the download; [start] then throws.
  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> delete() => _tryDelete(file);
}

/// Deletes everything in [dir] except the finished download named [keep], including
/// unfinished downloads (a new one starts from scratch).
Future<void> deleteOtherDownloads(Directory dir, {required String keep}) async {
  if (!await dir.exists()) {
    await dir.create(recursive: true);
    return;
  }
  await for (final entity in dir.list()) {
    final name = entity.path.substring(entity.path.lastIndexOf(Platform.pathSeparator) + 1);
    if (name != keep) await _tryDelete(entity);
  }
}

Future<void> _tryDelete(FileSystemEntity entity) async {
  try {
    await entity.delete(recursive: true);
  } on FileSystemException {
    // Already gone.
  }
}
