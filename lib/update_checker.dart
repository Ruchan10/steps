import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'step_service.dart';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.currentVersion,
    required this.url,
    required this.notes,
  });

  final String version;
  final String currentVersion;

  /// Direct link to the APK for this device's CPU, or the release page as a fallback.
  final String url;
  final String notes;
}

/// Checks the latest GitHub release of this app.
class UpdateChecker {
  /// "owner/repo", set by the release workflow. Empty in local builds, which disables the check.
  static const repo = String.fromEnvironment('GITHUB_REPO');

  /// Returns the newer release, or null if up to date / offline / not configured.
  static Future<AppUpdate?> check() async {
    if (repo.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final info = await StepService.getAppInfo();
      final request = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'footnote-app');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) return null;
      final json = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;

      final latest = (json['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      if (!isNewerVersion(latest, info.version)) return null;

      final assets = (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
      return AppUpdate(
        version: latest,
        currentVersion: info.version,
        url: apkUrlForAbis(assets, info.abis) ?? json['html_url'] as String,
        notes: (json['body'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null; // Offline, rate-limited, malformed response... try again next launch.
    } finally {
      client.close();
    }
  }
}

/// Picks the APK matching the most preferred supported ABI. Assets are named
/// `footnote-<version>-<abi>.apk` by the release workflow.
String? apkUrlForAbis(List<Map<String, dynamic>> assets, List<String> abis) {
  for (final abi in abis) {
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('-$abi.apk')) return asset['browser_download_url'] as String?;
    }
  }
  return null;
}

/// Compares dotted versions numerically: "1.10.0" > "1.9.2". Ignores "+build" and "-pre" suffixes.
bool isNewerVersion(String candidate, String current) {
  List<int> parse(String v) =>
      v.split(RegExp('[+-]')).first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final a = parse(candidate);
  final b = parse(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
