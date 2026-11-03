import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';
import 'metrics.dart';
import 'step_service.dart';

// Numbers and dates follow Intl.defaultLocale, which the app sets to its
// language (see StepsApp): "12,345" in English, "१२,३४५" in Nepali.

/// 12345 -> "12,345"
String formatSteps(int n) => NumberFormat.decimalPattern().format(n);

/// One decimal below 100 ("4.2"), whole numbers from there ("123").
String formatDecimal(double value) => value < 100 ? NumberFormat('0.0').format(value) : formatSteps(value.round());

String weekdayShort(DateTime d) => DateFormat.E().format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", or e.g. "Mon, 14 Oct".
String formatDay(DateTime d, AppLocalizations l) {
  final today = dateOnly(DateTime.now());
  final diff = today.difference(dateOnly(d)).inDays;
  if (diff == 0) return l.today;
  if (diff == 1) return l.yesterday;
  return DateFormat(d.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y').format(d);
}

/// Last [days] calendar days (oldest first) with 0 for days without records.
/// [todaySteps] overrides the stored value for today with the live count.
List<DaySteps> lastNDays(List<DaySteps> history, int days, {int? todaySteps}) {
  final byDate = {for (final d in history) dateOnly(d.date): d.steps};
  final today = dateOnly(DateTime.now());
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        final steps = i == 0 && todaySteps != null ? todaySteps : byDate[day] ?? 0;
        return DaySteps(day, steps);
      }(),
  ];
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Values with their unit, in the app's language.
extension UnitFormatting on AppLocalizations {
  String distanceValue(DistanceUnit unit, double value) => switch (unit) {
        DistanceUnit.km => distanceKm(formatDecimal(value)),
        DistanceUnit.mi => distanceMi(formatDecimal(value)),
      };

  String energyValue(EnergyUnit unit, num value) => switch (unit) {
        EnergyUnit.kcal => energyKcal(formatSteps(value.round())),
        EnergyUnit.kj => energyKj(formatSteps(value.round())),
      };

  String formatDistance(BodyProfile profile, int steps) =>
      distanceValue(profile.distanceUnit, profile.distance(steps));

  String formatEnergy(BodyProfile profile, int steps) => energyValue(profile.energyUnit, profile.energy(steps));

  /// "170 cm", or "5 ft 7 in" for imperial profiles.
  String formatHeight(BodyProfile profile) {
    if (!profile.imperial) return heightCm(formatSteps(profile.heightCm));
    final inches = (profile.heightCm / 2.54).round();
    return heightFtIn(formatSteps(inches ~/ 12), formatSteps(inches % 12));
  }

  /// "70 kg", or "154 lb" for imperial profiles.
  String formatWeight(BodyProfile profile) => profile.imperial
      ? weightLb(formatSteps((profile.weightKg * 2.20462).round()))
      : weightKg(formatSteps(profile.weightKg));
}
