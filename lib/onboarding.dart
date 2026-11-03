import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'format.dart';
import 'metrics.dart';
import 'profile_sheet.dart';
import 'step_service.dart';

/// First-run setup: welcome and language, physical activity permission,
/// the tracking notification, then height and weight.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.status,
    required this.onRefreshStatus,
    required this.onLanguageChanged,
    required this.onFinished,
  });

  final TrackingStatus status;

  /// Re-reads [status], e.g. after a permission dialog.
  final Future<void> Function() onRefreshStatus;
  final ValueChanged<String?> onLanguageChanged;

  /// Called with the entered details, or null when skipped.
  final ValueChanged<BodyProfile?> onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _pageCount = 4;

  final _pages = PageController();
  int _page = 0;
  bool _activityBlocked = false;
  bool _notificationsBlocked = false;
  late BodyProfile? _details = widget.status.profileSet ? widget.status.profile : null;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    HapticFeedback.selectionClick();
    // Don't carry the keyboard over from the details page.
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _next() => _goTo(_page + 1);

  Future<void> _request(AppPermission permission) async {
    final activity = permission == AppPermission.activity;
    if (activity ? _activityBlocked : _notificationsBlocked) {
      // The status is refreshed when the user comes back from settings.
      await (activity ? StepService.openAppSettings() : StepService.openNotificationSettings());
      return;
    }
    final result = await StepService.requestPermission(permission);
    await widget.onRefreshStatus();
    if (!mounted) return;
    setState(() {
      if (activity) {
        _activityBlocked = result == PermissionResult.blocked;
      } else {
        _notificationsBlocked = result == PermissionResult.blocked;
      }
    });
    if (result == PermissionResult.granted) {
      HapticFeedback.mediumImpact();
      // Let the check mark show before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted && _page == (activity ? 1 : 2)) _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: AnimatedOpacity(
                        opacity: _page > 0 ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: _page > 0 ? BackButton(onPressed: () => _goTo(_page - 1)) : null,
                      ),
                    ),
                    Expanded(child: Center(child: _PageDots(count: _pageCount, index: _page))),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_welcome(), _activity(), _notifications(), _aboutYou()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    final theme = Theme.of(context);
    final l = context.l10n;
    return _OnboardingPage(
      illustration: CircleAvatar(
        radius: 64,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Footprints(size: 72, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: l.appName,
      titleStyle: theme.textTheme.displaySmall,
      subtitle: l.tagline,
      body: l.welcomeBody,
      extra: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'en', label: Text('English')),
          ButtonSegment(value: 'ne', label: Text('नेपाली')),
        ],
        selected: {Localizations.localeOf(context).languageCode},
        showSelectedIcon: false,
        onSelectionChanged: (s) => widget.onLanguageChanged(s.first),
      ),
      primary: FilledButton(onPressed: _next, child: Text(l.getStarted)),
    );
  }

  Widget _activity() {
    final l = context.l10n;
    final granted = widget.status.permissionGranted;
    return _OnboardingPage(
      illustration: _Badge(icon: Icons.directions_walk, done: granted),
      title: l.activityTitle,
      body: _activityBlocked && !granted ? l.activityBlockedBody : l.activityBody,
      extra: granted ? _DoneChip(label: l.allowed) : null,
      primary: granted
          ? FilledButton(onPressed: _next, child: Text(l.continueButton))
          : FilledButton.icon(
              onPressed: () => _request(AppPermission.activity),
              icon: Icon(_activityBlocked ? Icons.settings_outlined : Icons.check),
              label: Text(_activityBlocked ? l.openSettings : l.allow),
            ),
    );
  }

  Widget _notifications() {
    final l = context.l10n;
    final allowed = widget.status.notificationsAllowed;
    return _OnboardingPage(
      illustration: _Badge(icon: Icons.notifications_active_outlined, done: allowed),
      title: l.notificationTitle,
      body: _notificationsBlocked && !allowed ? l.notificationBlockedBody : l.notificationBody,
      extra: _NotificationPreview(profile: _details ?? widget.status.profile, goal: widget.status.goal),
      primary: allowed
          ? FilledButton(onPressed: _next, child: Text(l.continueButton))
          : FilledButton.icon(
              onPressed: () => _request(AppPermission.notifications),
              icon: Icon(_notificationsBlocked ? Icons.settings_outlined : Icons.notifications_outlined),
              label: Text(_notificationsBlocked ? l.openSettings : l.allowNotifications),
            ),
      secondary: allowed ? null : TextButton(onPressed: _next, child: Text(l.skip)),
    );
  }

  Widget _aboutYou() {
    final l = context.l10n;
    final details = _details;
    return _OnboardingPage(
      illustration: const _Badge(icon: Icons.person_outline, radius: 40),
      title: l.detailsTitle,
      body: l.detailsBody,
      extra: ProfileForm(
        initial: details ?? widget.status.profile,
        startEmpty: details == null,
        onChanged: (profile) => setState(() => _details = profile),
        onSubmitted: details == null ? null : () => widget.onFinished(details),
      ),
      primary: FilledButton(
        onPressed: details == null ? null : () => widget.onFinished(details),
        child: Text(l.startCounting),
      ),
      secondary: TextButton(onPressed: () => widget.onFinished(null), child: Text(l.skip)),
    );
  }
}

/// Illustration, text and buttons, with the buttons kept at the bottom.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.illustration,
    required this.title,
    this.titleStyle,
    this.subtitle,
    required this.body,
    this.extra,
    required this.primary,
    this.secondary,
  });

  final Widget illustration;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final String body;
  final Widget? extra;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    illustration,
                    const SizedBox(height: 32),
                    Text(title, style: titleStyle ?? theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    if (extra != null) ...[const SizedBox(height: 28), extra!],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: primary,
          ),
          SizedBox(height: 48, child: Center(child: secondary)),
        ],
      ),
    );
  }
}

/// Icon in a tinted circle that turns into a check mark once [done].
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.done = false, this.radius = 56});

  final IconData icon;
  final bool done;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? scheme.primary : scheme.primaryContainer,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(
          done ? Icons.check : icon,
          key: ValueKey(done),
          size: radius,
          color: done ? scheme.onPrimary : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _DoneChip extends StatelessWidget {
  const _DoneChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.check_circle, color: scheme.primary),
      label: Text(label),
      side: BorderSide.none,
      backgroundColor: scheme.secondaryContainer,
    );
  }
}

/// What the tracking notification looks like, with sample numbers.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.profile, required this.goal});

  final BodyProfile profile;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    final steps = (goal * 0.62).round();
    return ExcludeSemantics(
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary,
                child: Footprints(size: 18, color: scheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.appName, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(l.notificationPreviewTitle(formatSteps(steps)), style: theme.textTheme.titleSmall),
                    Text(
                      l.notificationPreviewText(
                        l.formatDistance(profile, steps),
                        l.formatEnergy(profile, steps),
                        formatSteps(goal),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: steps / goal,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.stepOfTotal(formatSteps(index + 1), formatSteps(count)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= index ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
