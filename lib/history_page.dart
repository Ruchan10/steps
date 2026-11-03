import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'format.dart';
import 'metrics.dart';
import 'step_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.goal,
    required this.profile,
    required this.visible,
    required this.onEditDistance,
    required this.onEditEnergy,
  });

  final int goal;
  final BodyProfile profile;
  final VoidCallback onEditDistance;
  final VoidCallback onEditEnergy;

  /// Reloads from storage each time the tab becomes visible.
  final bool visible;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with AutomaticKeepAliveClientMixin {
  StreamSubscription<int>? _sub;
  List<DaySteps> _history = const [];
  int? _todayLive;
  int _range = 7;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = StepService.todaySteps().listen((steps) => setState(() => _todayLive = steps));
    _load();
  }

  @override
  void didUpdateWidget(HistoryPage old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final history = await StepService.getHistory();
    if (mounted) setState(() => _history = history);
  }

  /// Stored history with today's entry replaced by the live count.
  List<DaySteps> get _days {
    final live = _todayLive;
    if (live == null) return _history;
    final today = dateOnly(DateTime.now());
    final rest = _history.where((d) => dateOnly(d.date) != today);
    return [if (live > 0 || _history.isNotEmpty) DaySteps(today, live), ...rest];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l = context.l10n;
    final days = _days;
    final chartDays = lastNDays(days, _range, todaySteps: _todayLive);
    final total = chartDays.fold(0, (sum, d) => sum + d.steps);
    final best = chartDays.fold(0, (m, d) => math.max(m, d.steps));
    final goalDays = chartDays.where((d) => d.steps >= widget.goal).length;
    final profile = widget.profile;
    String count(double v) => formatSteps(v.round());

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.history, style: theme.textTheme.headlineMedium)),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 7, label: Text(l.range7)),
                        ButtonSegment(value: 30, label: Text(l.range30)),
                      ],
                      selected: {_range},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        setState(() => _range = s.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        StepsBarChart(days: chartDays, goal: widget.goal),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _Stat(label: l.totalSteps, value: total.toDouble(), format: count),
                            _Stat(label: l.dailyAvg, value: (total ~/ _range).toDouble(), format: count),
                            _Stat(label: l.bestDay, value: best.toDouble(), format: count),
                            _Stat(
                              label: l.goalMet,
                              value: goalDays.toDouble(),
                              format: (v) => '${count(v)}/${formatSteps(_range)}',
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            _Stat(
                              label: l.distance,
                              value: profile.distance(total),
                              format: (v) => l.distanceValue(profile.distanceUnit, v),
                              onTap: widget.onEditDistance,
                            ),
                            _Stat(
                              label: l.calories,
                              value: profile.energy(total).toDouble(),
                              format: (v) => l.energyValue(profile.energyUnit, v),
                              onTap: widget.onEditEnergy,
                            ),
                            _Stat(
                              label: l.avgDistance,
                              value: profile.distance(total ~/ _range),
                              format: (v) => l.distanceValue(profile.distanceUnit, v),
                              onTap: widget.onEditDistance,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(l.allDays, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l.noStepsYet,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) => _DayTile(day: days[i], goal: widget.goal, profile: profile),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.format, this.onTap});

  final String label;
  final double value;
  final String Function(double) format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stat = Column(
      children: [
        // Numbers roll to their new value when switching ranges.
        TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FittedBox(
            child: Text(
              format(v),
              style: theme.textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
    return Expanded(
      child: onTap == null
          ? stat
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: stat),
            ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.goal, required this.profile});

  final DaySteps day;
  final int goal;
  final BodyProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final reached = day.steps >= goal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDay(day.date, l), style: theme.textTheme.bodyLarge),
                    Text(
                      '${l.formatDistance(profile, day.steps)} · ${l.formatEnergy(profile, day.steps)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (reached) ...[
                Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(formatSteps(day.steps), style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: goal == 0 ? 0 : (day.steps / goal).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
