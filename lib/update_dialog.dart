import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'l10n/app_localizations.dart';
import 'step_service.dart';
import 'update_checker.dart';

/// Offers [update]: downloads the APK for this phone, then opens Android's installer.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) =>
    showDialog<void>(context: context, builder: (_) => UpdateDialog(update: update));

/// App name and version, with a button to check for updates. Completes with the update
/// found, for the caller to offer once the sheet is closed.
Future<AppUpdate?> showAboutSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<AppUpdate>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _AboutSheet(),
  );
}

enum _Phase { offer, downloading, readyToInstall, failed }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.update});

  final AppUpdate update;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  var _phase = _Phase.offer;
  ApkDownload? _download;
  int _received = 0;
  int _total = 0;

  /// In the failed phase: the file arrived but didn't match its checksum.
  bool _damaged = false;

  /// Bumped by every download attempt and by Cancel, so an older attempt stops quietly.
  int _attempt = 0;

  UpdateApk get _apk => widget.update.apk!;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    HapticFeedback.selectionClick();
    final attempt = ++_attempt;
    bool current() => mounted && attempt == _attempt;
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = _apk.size;
    });
    try {
      final download = ApkDownload(_apk, Directory(await StepService.getUpdateDir()));
      if (!current()) return;
      _download = download;

      // Downloaded before, and the installer was closed: that copy will do if it's intact.
      if (await download.file.exists()) {
        final result = await StepService.installUpdate(download.file.path, _apk.sha256);
        if (!current()) return;
        if (result == InstallResult.started) {
          _setPhase(_Phase.readyToInstall);
          return;
        }
        if (result == InstallResult.noInstaller) {
          _openReleasePage();
          return;
        }
        // Damaged or gone: download it again.
      }

      await download.start(onProgress: (received, total) {
        if (current()) _onProgress(received, total);
      });
    } catch (_) {
      if (current()) {
        _damaged = false;
        _setPhase(_Phase.failed);
      }
      return;
    }
    if (current()) await _install();
  }

  void _cancel() {
    _attempt++;
    _download?.cancel();
    _setPhase(_Phase.offer);
  }

  void _onProgress(int received, int total) {
    // Repaints once per percent rather than for every chunk from the network.
    final before = _total > 0 ? _received * 100 ~/ _total : 0;
    final after = total > 0 ? received * 100 ~/ total : 0;
    _received = received;
    _total = total;
    if (after != before && mounted) setState(() {});
  }

  /// Hands the downloaded APK to Android's installer.
  Future<void> _install() async {
    final download = _download;
    if (download == null) return;
    // Apps can't open the installer from the background; the user taps Install on return.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      _setPhase(_Phase.readyToInstall);
      return;
    }

    HapticFeedback.selectionClick();
    final result = await StepService.installUpdate(download.file.path, _apk.sha256);
    if (!mounted) return;
    switch (result) {
      case InstallResult.started:
        _setPhase(_Phase.readyToInstall);
      case InstallResult.badChecksum:
        await download.delete();
        _damaged = true;
        _setPhase(_Phase.failed);
      case InstallResult.missing:
        _damaged = false;
        _setPhase(_Phase.failed);
      case InstallResult.noInstaller:
        _openReleasePage();
    }
  }

  void _setPhase(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  void _openReleasePage() {
    Navigator.pop(context);
    StepService.openUrl(widget.update.releaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final update = widget.update;
    final apk = update.apk;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final List<Widget> status = switch (_phase) {
      _Phase.offer => [
          Text(l.updateBody(update.version, update.currentVersion)),
          if (apk != null) ...[
            const SizedBox(height: 4),
            Text(l.updateSize(_size(l, apk.size)), style: muted),
          ],
          if (apk != null && update.askToInstall) ...[
            const SizedBox(height: 12),
            Text(l.installPermissionHint, style: muted),
          ],
        ],
      _Phase.downloading => [
          LinearProgressIndicator(value: _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null),
          const SizedBox(height: 8),
          Text(l.updateDownloading(_size(l, _received), _size(l, _total)), style: muted),
        ],
      _Phase.readyToInstall => [Text(l.updateReady)],
      _Phase.failed => [
          Text(_damaged ? l.updateDamaged : l.updateFailed, style: TextStyle(color: theme.colorScheme.error)),
        ],
    };

    final later = TextButton(onPressed: () => Navigator.pop(context), child: Text(l.later));
    final List<Widget> actions = switch (_phase) {
      _Phase.offer when apk == null => [
          later,
          FilledButton.icon(onPressed: _openReleasePage, icon: const Icon(Icons.open_in_new), label: Text(l.download)),
        ],
      _Phase.offer => [
          later,
          FilledButton.icon(onPressed: _start, icon: const Icon(Icons.download), label: Text(l.update)),
        ],
      _Phase.downloading => [TextButton(onPressed: _cancel, child: Text(l.cancel))],
      _Phase.readyToInstall => [
          later,
          FilledButton.icon(onPressed: _install, icon: const Icon(Icons.install_mobile), label: Text(l.install)),
        ],
      _Phase.failed => [
          later,
          FilledButton.icon(onPressed: _start, icon: const Icon(Icons.refresh), label: Text(l.tryAgain)),
        ],
    };

    return PopScope(
      // Cancel first: closing mid-download would leave it running unseen.
      canPop: _phase != _Phase.downloading,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_outlined),
        title: Text(l.updateTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...status,
                  if (update.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.whatsNew, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(update.notes, style: muted),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: actions,
      ),
    );
  }
}

/// "7.2 MB", with digits in the app's language.
String _size(AppLocalizations l, int bytes) => l.sizeMb(formatDecimal(bytes / 1000000));

enum _CheckState { idle, checking, upToDate, failed }

class _AboutSheet extends StatefulWidget {
  const _AboutSheet();

  @override
  State<_AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<_AboutSheet> {
  String? _version;
  var _check = _CheckState.idle;

  @override
  void initState() {
    super.initState();
    StepService.getAppInfo().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _checkNow() async {
    HapticFeedback.selectionClick();
    setState(() => _check = _CheckState.checking);
    try {
      final update = await UpdateChecker.check();
      if (!mounted) return;
      if (update != null) {
        Navigator.pop(context, update);
        return;
      }
      setState(() => _check = _CheckState.upToDate);
    } catch (_) {
      if (mounted) setState(() => _check = _CheckState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final version = _version;
    final checking = _check == _CheckState.checking;
    final message = switch (_check) {
      _CheckState.upToDate => l.upToDate,
      _CheckState.failed => l.updateCheckFailed,
      _ => null,
    };
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.directions_walk, size: 28, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.appName, style: theme.textTheme.titleLarge),
                      if (version != null) Text(l.versionNumber(version), style: muted),
                    ],
                  ),
                ),
              ],
            ),
            if (UpdateChecker.enabled) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: checking ? null : _checkNow,
                icon: checking
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(l.checkForUpdates),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: _check == _CheckState.failed ? muted?.copyWith(color: theme.colorScheme.error) : muted,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
