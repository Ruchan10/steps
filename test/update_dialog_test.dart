import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:steps/l10n/app_localizations.dart';
import 'package:steps/update_checker.dart';
import 'package:steps/update_dialog.dart';

const _apk = UpdateApk(
  abi: 'arm64-v8a',
  name: 'footnote-1.2.0-arm64-v8a.apk',
  url: 'https://example.com/footnote-1.2.0-arm64-v8a.apk',
  size: 7200000,
  sha256: '',
);

const _update = AppUpdate(
  version: '1.2.0',
  currentVersion: '1.1.0',
  notes: '- Faster widgets',
  releaseUrl: 'https://github.com/owner/repo/releases/tag/v1.2.0',
  apk: _apk,
);

const _methods = MethodChannel('steps/methods');

/// Opens [open] from a button in an app set to [locale].
Future<void> _pumpAndOpen(WidgetTester tester, void Function(BuildContext) open, {String locale = 'en'}) async {
  Intl.defaultLocale = locale;
  addTearDown(() => Intl.defaultLocale = null);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => open(context), child: const Text('open'))),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void _mockMethods(Future<Object?> Function(MethodCall call) handler) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_methods, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(_methods, null));
}

void main() {
  testWidgets('offers the update with its size and notes', (tester) async {
    await _pumpAndOpen(tester, (context) => showUpdateDialog(context, _update));
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Version 1.2.0 is ready to download. You have 1.1.0.'), findsOneWidget);
    expect(find.text('Download size: 7.2 MB'), findsOneWidget);
    expect(find.text('- Faster widgets'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.textContaining('Android will ask'), findsNothing);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('reads in Nepali', (tester) async {
    await _pumpAndOpen(tester, (context) => showUpdateDialog(context, _update), locale: 'ne');
    expect(find.text('नयाँ संस्करण उपलब्ध छ'), findsOneWidget);
    expect(find.text('डाउनलोड साइज: ७.२ एमबी'), findsOneWidget);
    expect(find.text('अपडेट गर्नुहोस्'), findsOneWidget);
  });

  testWidgets('warns that Android will ask to allow installing', (tester) async {
    const update = AppUpdate(
      version: '1.2.0',
      currentVersion: '1.1.0',
      notes: '',
      releaseUrl: '',
      apk: _apk,
      askToInstall: true,
    );
    await _pumpAndOpen(tester, (context) => showUpdateDialog(context, update));
    expect(find.text("Android will ask you to let Footnote install apps. It's only used for updates."), findsOneWidget);
    expect(find.text("What's new"), findsNothing);
  });

  testWidgets('without an APK for this phone, opens the release page', (tester) async {
    final opened = <String>[];
    _mockMethods((call) async {
      if (call.method == 'openUrl') opened.add((call.arguments as Map)['url'] as String);
      return true;
    });
    const update = AppUpdate(version: '1.2.0', currentVersion: '1.1.0', notes: '', releaseUrl: 'https://example.com/r');
    await _pumpAndOpen(tester, (context) => showUpdateDialog(context, update));
    expect(find.textContaining('Download size'), findsNothing);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(opened, ['https://example.com/r']);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('shows the error and a retry when the download fails', (tester) async {
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('footnote_dialog_test'));
    addTearDown(() => tester.runAsync(() => dir!.delete(recursive: true)));
    _mockMethods((call) async => call.method == 'getUpdateDir' ? dir!.path : null);

    await _pumpAndOpen(tester, (context) => showUpdateDialog(context, _update));
    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // flutter_test answers every HTTP request with 400, so the download fails.
    for (var i = 0; i < 20 && find.text('Try again').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text("Couldn't download the update. Check your internet connection and try again."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(dir!.listSync(), isEmpty);
  });

  testWidgets('about sheet shows the version', (tester) async {
    _mockMethods((call) async => call.method == 'getAppInfo' ? {'version': '1.1.0', 'versionCode': 1001000} : null);
    await _pumpAndOpen(tester, (context) => showAboutSheet(context));
    expect(find.text('Footnote'), findsOneWidget);
    expect(find.text('Version 1.1.0'), findsOneWidget);
    // Updates are off in test and local builds (no GITHUB_REPO).
    expect(find.text('Check for updates'), findsNothing);
  });
}
