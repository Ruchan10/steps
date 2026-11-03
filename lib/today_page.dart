import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'format.dart';
import 'metrics.dart';
import 'profile_sheet.dart';
import 'step_service.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.goal,
    required this.onGoalChanged,
    required this.profile,
    required this.onEditProfile,
    required this.onEditDistance,
    required this.onEditEnergy,
    required this.onEditLanguage,
    required this.showBatteryBanner,
    required this.onFixBattery,
    required this.onDismissBattery,
  });

  final int goal;
  final ValueChanged<int> onGoalChanged;
  final BodyProfile profile;
  final VoidCallback onEditProfile;
  final VoidCallback onEditDistance;
  final VoidCallback onEditEnergy;
  final VoidCallback onEditLanguage;
  final bool showBatteryBanner;
  final VoidCallback onFixBattery;
  final VoidCallback onDismissBattery;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with AutomaticKeepAliveClientMixin {
  StreamSubscription<int>? _sub;
  late final AppLifecycleListener _lifecycle;
  int _steps = 0;
  List<DaySteps> _history = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = StepService.todaySteps().listen((steps) => setState(() => _steps = steps));
    _lifecycle = AppLifecycleListener(onResume: _loadHistory);
    _loadHistory();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await StepService.getHistory(limit: 7);
    if (mounted) setState(() => _history = history);
  }

  Future<void> _editGoal() async {
    HapticFeedback.selectionClick();
    final goal = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(initial: widget.goal),
    );
    if (goal != null && goal != widget.goal) widget.onGoalChanged(goal);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l = context.l10n;
    final goal = widget.goal;
    final remaining = goal - _steps;
    final profile = widget.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(l.today, style: theme.textTheme.headlineMedium)),
            IconButton(
              onPressed: widget.onEditLanguage,
              icon: const Icon(Icons.translate),
              tooltip: l.language,
            ),
            IconButton(
              onPressed: widget.onEditProfile,
              icon: const Icon(Icons.person_outline),
              tooltip: l.yourDetails,
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.showBatteryBanner
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _BatteryBanner(onFix: widget.onFixBattery, onDismiss: widget.onDismissBattery),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 32),
        Center(
          child: GoalRing(
            progress: goal == 0 ? 0 : _steps / goal,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, color: theme.colorScheme.primary, size: 32),
                AnimatedNumber(
                  value: _steps.toDouble(),
                  format: (v) => formatSteps(v.round()),
                  style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(l.steps, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              remaining > 0 ? l.stepsToGo(formatSteps(remaining)) : l.goalReached,
              key: ValueKey(remaining > 0),
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ActionChip(
            avatar: const Icon(Icons.flag_outlined, size: 18),
            label: Text(l.goalChip(formatSteps(goal))),
            onPressed: _editGoal,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.place_outlined,
                label: l.distance,
                value: profile.distance(_steps),
                format: (v) => l.distanceValue(profile.distanceUnit, v),
                onTap: widget.onEditDistance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.local_fire_department_outlined,
                label: l.calories,
                value: profile.energy(_steps).toDouble(),
                format: (v) => l.energyValue(profile.energyUnit, v),
                onTap: widget.onEditEnergy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.last7Days, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                StepsBarChart(days: lastNDays(_history, 7, todaySteps: _steps), goal: goal, height: 140),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Number that rolls smoothly to new values instead of jumping.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.format, this.style});

  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        format(v),
        // Fixed-width digits so the number doesn't wobble while it changes.
        style: (style ?? DefaultTextStyle.of(context).style)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double value;
  final String Function(double) format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer)),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedNumber(
                  value: value,
                  format: format,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryBanner extends StatelessWidget {
  const _BatteryBanner({required this.onFix, required this.onDismiss});

  final VoidCallback onFix;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.battery_alert_outlined, color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.batteryTitle,
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.batteryBody,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(foregroundColor: scheme.onTertiaryContainer),
                  child: Text(l.notNow),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onFix,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.tertiary,
                    foregroundColor: scheme.onTertiary,
                  ),
                  child: Text(l.setUnrestricted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initial});

  final int initial;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const _presets = [5000, 6000, 8000, 10000, 12000, 15000, 20000];

  late final _controller = TextEditingController(text: '${widget.initial}');
  late int? _value = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int goal) {
    HapticFeedback.selectionClick();
    setState(() => _value = goal);
    _controller.text = '$goal';
  }

  void _submit() {
    final value = _value;
    if (value != null && value > 0) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.dailyGoal, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(formatSteps(p)),
                    selected: _value == p,
                    onSelected: (_) => _pick(p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [const DigitsFormatter(), LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(
                labelText: l.customGoal,
                suffixText: l.steps,
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) => setState(() => _value = int.tryParse(text)),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_value ?? 0) > 0 ? _submit : null,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
