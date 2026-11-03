import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'format.dart';
import 'step_service.dart';

/// Circular progress ring towards the daily goal.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.progress, required this.child, this.size = 260});

  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(value, scheme.primary, scheme.surfaceContainerHighest),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Simple daily bar chart with a dashed goal line. [days] is oldest first.
class StepsBarChart extends StatelessWidget {
  const StepsBarChart({super.key, required this.days, required this.goal, this.height = 180});

  final List<DaySteps> days;
  final int goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Repaints the day labels when the language changes.
    final locale = Localizations.localeOf(context);
    // Bars grow in on first show and whenever the range changes.
    return TweenAnimationBuilder<double>(
      key: ValueKey(days.length),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarsPainter(
            days: days,
            goal: goal,
            growth: t,
            bar: theme.colorScheme.primary,
            barMuted: theme.colorScheme.primary.withValues(alpha: 0.45),
            goalLine: theme.colorScheme.outline,
            labelStyle: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
            locale: locale,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.days,
    required this.goal,
    required this.growth,
    required this.bar,
    required this.barMuted,
    required this.goalLine,
    required this.labelStyle,
    required this.locale,
  });

  final List<DaySteps> days;
  final int goal;
  final double growth;
  final Color bar;
  final Color barMuted;
  final Color goalLine;
  final TextStyle labelStyle;
  final Locale locale;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;
    final maxSteps = days.map((d) => d.steps).fold(goal, math.max).toDouble();
    final slot = size.width / days.length;
    final barWidth = math.min(slot * 0.6, 28.0);
    // With many bars, only label every Nth day to avoid overlap.
    final labelEvery = days.length <= 7 ? 1 : (days.length / 6).ceil();

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = slot * i + slot / 2;
      final h = maxSteps == 0 ? 0.0 : chartHeight * d.steps / maxSteps * growth;
      if (h > 0) {
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(x - barWidth / 2, chartHeight - h, barWidth, h),
          topLeft: Radius.circular(barWidth / 3),
          topRight: Radius.circular(barWidth / 3),
        );
        canvas.drawRRect(r, Paint()..color = d.steps >= goal ? bar : barMuted);
      }
      final fromEnd = days.length - 1 - i;
      if (fromEnd % labelEvery == 0) {
        final label = days.length <= 7 ? weekdayShort(d.date) : formatSteps(d.date.day);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 4));
      }
    }

    // Dashed goal line.
    final gy = chartHeight - chartHeight * goal / maxSteps;
    final dash = Paint()
      ..color = goalLine
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, gy), Offset(math.min(x + 4, size.width), gy), dash);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.days != days ||
      old.goal != goal ||
      old.growth != growth ||
      old.bar != bar ||
      old.labelStyle != labelStyle ||
      old.locale != locale;
}

/// The app's footprints mark (android/.../res/drawable/ic_steps.xml).
class Footprints extends StatelessWidget {
  const Footprints({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _FootprintsPainter(color ?? IconTheme.of(context).color ?? const Color(0xFF000000)),
      );
}

class _FootprintsPainter extends CustomPainter {
  _FootprintsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Same ellipses as the vector drawable, on its 24x24 grid.
    canvas.scale(size.width / 24);
    final paint = Paint()..color = color;
    for (final (cx, cy, rx, ry) in const [(8.0, 7.5, 3.0, 4.5), (8.0, 15.5, 2.3, 2.5), (16.0, 10.5, 3.0, 4.5), (16.0, 18.5, 2.3, 2.5)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), paint);
    }
  }

  @override
  bool shouldRepaint(_FootprintsPainter old) => old.color != color;
}
