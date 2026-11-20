import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steps/step_service.dart';
import 'package:steps/update_checker.dart';

// Plain tests only (no testWidgets), so HttpClient talks to a real local server.

const _installed = AppInfo(version: '1.1.0', versionCode: 1001000, abis: ['arm64-v8a', 'armeabi-v7a', 'armeabi']);

/// An update.json like .github/scripts/release.py writes.
Map<String, dynamic> _manifest({
  String version = '1.2.0',
  int versionCode = 1002000,
  List<String> abis = const ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'universal'],
}) =>
    {
      'version': version,
      'versionCode': versionCode,
      'tag': 'v$version',
      'releaseUrl': 'https://github.com/owner/repo/releases/tag/v$version',
      'notes': '- Faster widgets\n',
      'apks': [
        for (final abi in abis)
          {
            'abi': abi,
            'name': 'footnote-$version-$abi.apk',
            'url': 'https://example.com/footnote-$version-$abi.apk',
            'size': 7200000,
            'sha256': 'ab' * 32,
          },
      ],
    };

UpdateApk _apk(String abi) =>
    UpdateApk(abi: abi, name: '$abi.apk', url: 'https://example.com/$abi.apk', size: 1, sha256: '');

void main() {
  group('compareVersions', () {
    test('compares numerically', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.9'), isTrue);
      expect(isNewerVersion('2.0', '1.9.9'), isTrue);
      expect(isNewerVersion('v1.2.0', '1.1.0'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('ignores build numbers', () {
      expect(isNewerVersion('1.2.0+5', '1.2.0'), isFalse);
      expect(compareVersions('1.2.0+5', '1.2.0+9'), 0);
    });

    test('puts pre-releases before their release', () {
      expect(isNewerVersion('1.2.0', '1.2.0-beta.1'), isTrue);
      expect(isNewerVersion('1.2.0-beta.1', '1.2.0'), isFalse);
      expect(isNewerVersion('1.2.0-beta.1', '1.1.9'), isTrue);
      expect(compareVersions('1.2.0-alpha', '1.2.0-beta'), -1);
      expect(compareVersions('1.2.0-beta.2', '1.2.0-beta.10'), -1);
      expect(compareVersions('1.2.0-beta', '1.2.0-beta.1'), -1);
      expect(compareVersions('1.2.0-1', '1.2.0-rc'), -1);
      expect(compareVersions('1.2.0-rc.1', '1.2.0-rc.1'), 0);
    });
  });

  test("apkForAbis follows the phone's ABI order, then falls back to the universal APK", () {
    final all = [_apk('armeabi-v7a'), _apk('arm64-v8a'), _apk('x86_64'), _apk('universal')];
    expect(apkForAbis(all, ['arm64-v8a', 'armeabi-v7a'])?.abi, 'arm64-v8a');
    expect(apkForAbis(all, ['armeabi-v7a', 'armeabi'])?.abi, 'armeabi-v7a');
    expect(apkForAbis(all, ['x86'])?.abi, 'universal');
    expect(apkForAbis([_apk('arm64-v8a')], ['x86']), isNull);
  });

  group('updateFromManifest', () {
    test('offers a newer release with the APK for this phone', () {
      final update = updateFromManifest(_manifest(), _installed)!;
      expect(update.version, '1.2.0');
      expect(update.currentVersion, '1.1.0');
      expect(update.apk?.name, 'footnote-1.2.0-arm64-v8a.apk');
      expect(update.apk?.size, 7200000);
      expect(update.notes, '- Faster widgets');
      expect(update.askToInstall, isFalse);
    });

    test('is null when the app is up to date', () {
      expect(updateFromManifest(_manifest(version: '1.1.0', versionCode: 1001000), _installed), isNull);
      expect(updateFromManifest(_manifest(version: '1.0.9', versionCode: 1000009), _installed), isNull);
    });

    test('skips a release that Android would refuse as a downgrade', () {
      expect(updateFromManifest(_manifest(versionCode: 1000000), _installed), isNull);
    });

    test('falls back to the release page when no APK fits', () {
      final update = updateFromManifest(_manifest(abis: ['x86_64']), _installed)!;
      expect(update.apk, isNull);
      expect(update.releaseUrl, 'https://github.com/owner/repo/releases/tag/v1.2.0');
    });

    test('says when Android will ask to allow installing', () {
      const info = AppInfo(version: '1.1.0', versionCode: 1001000, abis: ['arm64-v8a'], canInstallUpdates: false);
      expect(updateFromManifest(_manifest(), info)?.askToInstall, isTrue);
    });
  });

  test('isPromptDue offers each version once a day', () {
    final now = DateTime(2026, 11, 17, 12);
    expect(isPromptDue('1.2.0', lastVersion: null, lastAt: null, now: now), isTrue);
    expect(isPromptDue('1.2.0', lastVersion: '1.1.0', lastAt: now, now: now), isTrue);
    final hourAgo = now.subtract(const Duration(hours: 1));
    expect(isPromptDue('1.2.0', lastVersion: '1.2.0', lastAt: hourAgo, now: now), isFalse);
    final dayAgo = now.subtract(const Duration(days: 1));
    expect(isPromptDue('1.2.0', lastVersion: '1.2.0', lastAt: dayAgo, now: now), isTrue);
  });

  group('over HTTP', () {
    late HttpServer server;
    late Directory dir;
    final routes = <String, Future<void> Function(HttpResponse)>{};

    Uri url(String path) => Uri.parse('http://${server.address.host}:${server.port}$path');

    UpdateApk apkAt(String path, {int size = 300000}) => UpdateApk(
          abi: 'arm64-v8a',
          name: 'footnote-1.2.0-arm64-v8a.apk',
          url: url(path).toString(),
          size: size,
          sha256: '',
        );

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final response = request.response;
        response.done.ignore();
        try {
          final route = routes[request.uri.path];
          if (route == null) {
            response.statusCode = HttpStatus.notFound;
          } else {
            await route(response);
          }
          await response.close();
        } catch (_) {
          // The client hung up (cancelled), or the route broke the response on purpose.
        }
      });
      dir = await Directory.systemTemp.createTemp('footnote_update_test');
    });

    tearDown(() async {
      routes.clear();
      await server.close(force: true);
      await dir.delete(recursive: true);
    });

    test("fetchManifest follows redirects, like GitHub's latest/download link", () async {
      routes['/releases/latest/download/update.json'] = (r) async =>
          r.redirect(url('/releases/download/v1.2.0/update.json'), status: HttpStatus.found);
      routes['/releases/download/v1.2.0/update.json'] = (r) async =>
          r.redirect(url('/assets/update.json'), status: HttpStatus.found);
      routes['/assets/update.json'] = (r) async => r.write(jsonEncode(_manifest()));

      final manifest = await fetchManifest(url('/releases/latest/download/update.json'));
      expect(manifest?['version'], '1.2.0');
      expect(updateFromManifest(manifest!, _installed)?.apk?.abi, 'arm64-v8a');
    });

    test('fetchManifest is null before the first release', () async {
      expect(await fetchManifest(url('/releases/latest/download/update.json')), isNull);
    });

    test('fetchManifest throws when GitHub has trouble', () async {
      routes['/update.json'] = (r) async => r.statusCode = HttpStatus.serviceUnavailable;
      await expectLater(fetchManifest(url('/update.json')), throwsA(isA<HttpException>()));
    });

    test('ApkDownload saves the APK, reports progress and clears older downloads', () async {
      final chunk = List.filled(100000, 7);
      routes['/app.apk'] = (r) async {
        r.contentLength = chunk.length * 3;
        for (var i = 0; i < 3; i++) {
          r.add(chunk);
          await r.flush();
        }
      };
      await File('${dir.path}/footnote-1.1.0-arm64-v8a.apk').writeAsString('old');
      await File('${dir.path}/footnote-1.2.0-arm64-v8a.apk.part').writeAsString('half');

      final progress = <(int, int)>[];
      final file = await ApkDownload(apkAt('/app.apk'), dir).start(onProgress: (r, t) => progress.add((r, t)));

      expect(await file.length(), 300000);
      expect(progress.last, (300000, 300000));
      expect(progress.map((p) => p.$1), orderedEquals([...progress.map((p) => p.$1)]..sort()));
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['footnote-1.2.0-arm64-v8a.apk']);
    });

    test('ApkDownload leaves nothing behind when the server fails', () async {
      routes['/app.apk'] = (r) async => r.statusCode = HttpStatus.internalServerError;
      await expectLater(ApkDownload(apkAt('/app.apk'), dir).start(), throwsA(isA<HttpException>()));
      expect(dir.listSync(), isEmpty);
    });

    test('ApkDownload leaves nothing behind when the connection drops', () async {
      routes['/app.apk'] = (r) async {
        r.contentLength = 300000;
        r.add(List.filled(100000, 7));
        await r.flush();
        // close() then fails (too few bytes) and the server drops the connection.
      };
      await expectLater(ApkDownload(apkAt('/app.apk'), dir).start(), throwsA(isA<HttpException>()));
      expect(dir.listSync(), isEmpty);
    });

    test('ApkDownload stops when cancelled', () async {
      final hold = Completer<void>();
      routes['/app.apk'] = (r) async {
        r.contentLength = 300000;
        r.add(List.filled(100000, 7));
        await r.flush();
        await hold.future; // Never sends the rest.
      };
      final download = ApkDownload(apkAt('/app.apk'), dir);
      await expectLater(download.start(onProgress: (_, _) => download.cancel()), throwsA(anything));
      expect(download.cancelled, isTrue);
      expect(dir.listSync(), isEmpty);
      hold.complete();
    });
  });
}
