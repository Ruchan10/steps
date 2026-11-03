import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'format.dart';
import 'history_page.dart';
import 'l10n/app_localizations.dart';
import 'metrics.dart';
import 'onboarding.dart';
import 'profile_sheet.dart';
import 'settings_sheets.dart';
import 'step_service.dart';
import 'today_page.dart';
import 'update_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Fetched while the native splash is still showing, so the first frame is the real UI.
  final status = await StepService.getStatus();
  runApp(StepsApp(initialStatus: status));
}

class StepsApp extends StatefulWidget {
  const StepsApp({super.key, required this.initialStatus});

  final TrackingStatus initialStatus;

  @override
  State<StepsApp> createState() => _StepsAppState();
}

class _StepsAppState extends State<StepsApp> {
  /// "en", "ne", or null to follow the phone's language.
  late String? _language = widget.initialStatus.language;

  void _setLanguage(String? language) {
    HapticFeedback.selectionClick();
    setState(() => _language = language);
    StepService.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final seed = Color(widget.initialStatus.accentColor ?? 0xFF3B6939);
    final language = _language;
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
          ),
        );
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: language == null ? null : Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (locales, supported) {
        final locale = basicLocaleListResolution(locales, supported);
        // Numbers and dates (lib/format.dart) follow the app's language too.
        Intl.defaultLocale = locale.toLanguageTag();
        return locale;
      },
      home: HomeShell(initialStatus: widget.initialStatus, language: language, onLanguageChanged: _setLanguage),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.initialStatus,
    required this.language,
    required this.onLanguageChanged,
  });

  final TrackingStatus initialStatus;
  final String? language;
  final ValueChanged<String?> onLanguageChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late TrackingStatus _status = widget.initialStatus;
  late int _goal = widget.initialStatus.goal;
  late BodyProfile _profile = widget.initialStatus.profile;
  late bool _onboarded = widget.initialStatus.onboarded;
  final _pages = PageController();
  int _tab = 0;
  bool _permissionBlocked = false;
  bool _batteryBannerDismissed = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-check when returning from system settings.
    _lifecycle = AppLifecycleListener(onResume: _refreshStatus);
    if (_status.permissionGranted) StepService.startTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    // Not in the middle of first-run setup.
    if (!_onboarded) return;
    final update = await UpdateChecker.check();
    if (update == null || !mounted) return;
    await showDialog<void>(context: context, builder: (_) => _UpdateDialog(update: update));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final status = await StepService.getStatus();
    if (status.sensorAvailable && status.permissionGranted) {
      await StepService.startTracking();
    }
    if (mounted) setState(() => _status = status);
  }

  Future<void> _requestPermission() async {
    if (_permissionBlocked) {
      await StepService.openAppSettings(); // _refreshStatus runs on resume
      return;
    }
    final result = await StepService.requestPermission(AppPermission.activity);
    if (!mounted) return;
    setState(() => _permissionBlocked = result == PermissionResult.blocked);
    await _refreshStatus();
  }

  Future<void> _fixBattery() async {
    final unrestricted = await StepService.requestBatteryUnrestricted();
    if (!mounted) return;
    if (unrestricted) HapticFeedback.mediumImpact();
    await _refreshStatus();
  }

  void _dismissBatteryBanner() => setState(() => _batteryBannerDismissed = true);

  void _setGoal(int goal) {
    HapticFeedback.mediumImpact();
    setState(() => _goal = goal);
    StepService.setGoal(goal);
  }

  void _setProfile(BodyProfile profile) {
    HapticFeedback.mediumImpact();
    setState(() => _profile = profile);
    StepService.setProfile(profile);
  }

  Future<void> _editProfile() async => _applyProfile(await showProfileSheet(context, _profile));

  Future<void> _editDistance() async => _applyProfile(await showDistanceSheet(context, _profile));

  Future<void> _editEnergy() async => _applyProfile(await showEnergySheet(context, _profile));

  void _applyProfile(BodyProfile? profile) {
    if (profile != null && profile != _profile) _setProfile(profile);
  }

  void _editLanguage() =>
      showLanguageSheet(context, current: widget.language, onChanged: widget.onLanguageChanged);

  Future<void> _finishOnboarding(BodyProfile? details) async {
    if (details != null) {
      // First time through, show distance in the same units as height and weight.
      _setProfile(
        _status.profileSet
            ? details
            : details.copyWith(distanceUnit: details.imperial ? DistanceUnit.mi : DistanceUnit.km),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() => _onboarded = true);
    await StepService.setOnboarded();
    await _refreshStatus();
  }

  void _selectTab(int i) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Widget _buildBody() {
    final l = context.l10n;
    if (!_status.sensorAvailable) {
      return _MessageScreen(
        key: const ValueKey('no-sensor'),
        icon: Icons.sensors_off_outlined,
        title: l.noSensorTitle,
        message: l.noSensorBody,
      );
    }
    if (!_onboarded) {
      return OnboardingFlow(
        key: const ValueKey('onboarding'),
        status: _status,
        onRefreshStatus: _refreshStatus,
        onLanguageChanged: widget.onLanguageChanged,
        onFinished: _finishOnboarding,
      );
    }
    if (!_status.permissionGranted) {
      return _MessageScreen(
        key: const ValueKey('permission'),
        icon: Icons.directions_walk,
        title: l.permissionTitle,
        message: _permissionBlocked ? l.activityBlockedBody : l.permissionBody,
        action: FilledButton.icon(
          onPressed: _requestPermission,
          icon: Icon(_permissionBlocked ? Icons.settings_outlined : Icons.check),
          label: Text(_permissionBlocked ? l.openSettings : l.allow),
        ),
      );
    }

    return Scaffold(
      key: const ValueKey('main'),
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pages,
          onPageChanged: (i) => setState(() => _tab = i),
          children: [
            TodayPage(
              goal: _goal,
              onGoalChanged: _setGoal,
              profile: _profile,
              onEditProfile: _editProfile,
              onEditDistance: _editDistance,
              onEditEnergy: _editEnergy,
              onEditLanguage: _editLanguage,
              showBatteryBanner: !_status.batteryUnrestricted && !_batteryBannerDismissed,
              onFixBattery: _fixBattery,
              onDismissBattery: _dismissBatteryBanner,
            ),
            HistoryPage(
              goal: _goal,
              profile: _profile,
              visible: _tab == 1,
              onEditDistance: _editDistance,
              onEditEnergy: _editEnergy,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.directions_walk_outlined),
            selectedIcon: const Icon(Icons.directions_walk),
            label: l.today,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l.history,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildBody(),
      ),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(icon, size: 56, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 32),
                Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[const SizedBox(height: 32), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.system_update_outlined),
      title: Text(l.updateTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.updateBody(update.version, update.currentVersion)),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l.whatsNew, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  update.notes,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.later)),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            StepService.openUrl(update.url);
          },
          icon: const Icon(Icons.download),
          label: Text(l.download),
        ),
      ],
    );
  }
}
