import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:steps/format.dart';
import 'package:steps/l10n/app_localizations.dart';
import 'package:steps/metrics.dart';
import 'package:steps/profile_sheet.dart';
import 'package:steps/step_service.dart';

void main() {
  test('formatSteps adds thousands separators', () {
    expect(formatSteps(0), '0');
    expect(formatSteps(999), '999');
    expect(formatSteps(1000), '1,000');
    expect(formatSteps(1234567), '1,234,567');
  });

  test('Nepali uses Devanagari digits and lakh grouping', () {
    Intl.withLocale('ne', () {
      expect(formatSteps(12345), '१२,३४५');
      expect(formatSteps(123456), '१,२३,४५६');
      expect(formatDecimal(4.24), '४.२');
    });
  });

  test('lastNDays fills gaps with zero and uses live count for today', () {
    final today = dateOnly(DateTime.now());
    final history = [
      DaySteps(today, 10),
      DaySteps(today.subtract(const Duration(days: 2)), 500),
    ];
    final days = lastNDays(history, 3, todaySteps: 42);
    expect(days.map((d) => d.steps), [500, 0, 42]);
    expect(days.last.date, today);
  });

  test('BodyProfile estimates distance and calories', () {
    final en = lookupAppLocalizations(const Locale('en'));
    const p = BodyProfile.defaults; // 170 cm, 70 kg, km, kcal
    // 170 cm * 0.415 = 0.7055 m stride -> 10,000 steps = 7.055 km
    expect(p.distanceKm(10000), closeTo(7.055, 0.001));
    expect(en.formatDistance(p, 10000), '7.1 km');
    expect(p.calories(10000), 385); // 7.055 km * 70 kg * 0.78
    expect(en.formatEnergy(p, 0), '0 kcal');

    final miles = p.copyWith(distanceUnit: DistanceUnit.mi);
    expect(en.formatDistance(miles, 10000), '4.4 mi');
    expect(miles.calories(10000), p.calories(10000));

    final kj = p.copyWith(energyUnit: EnergyUnit.kj);
    expect(kj.energy(10000), 1611); // 385.2 kcal * 4.184
    expect(en.formatEnergy(kj, 10000), '1,611 kJ');
  });

  test('units and body details read in Nepali', () {
    final ne = lookupAppLocalizations(const Locale('ne'));
    Intl.withLocale('ne', () {
      expect(ne.formatDistance(BodyProfile.defaults, 10000), '७.१ कि.मि.');
      expect(ne.formatEnergy(BodyProfile.defaults, 10000), '३८५ क्यालोरी');
      expect(ne.formatHeight(BodyProfile.defaults), '१७० से.मि.');
    });
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.formatHeight(BodyProfile.defaults.copyWith(imperial: true)), '5 ft 7 in');
    expect(en.formatWeight(BodyProfile.defaults.copyWith(imperial: true)), '154 lb');
  });

  test('profiles saved before units were separate keep their units', () {
    final old = BodyProfile.fromMap({'heightCm': 180, 'weightKg': 80, 'imperial': true});
    expect(old.heightCm, 180);
    expect(old.distanceUnit, DistanceUnit.mi);
    expect(old.energyUnit, EnergyUnit.kcal);
    final current = BodyProfile.fromMap(BodyProfile.defaults.copyWith(energyUnit: EnergyUnit.kj).toMap());
    expect(current, BodyProfile.defaults.copyWith(energyUnit: EnergyUnit.kj));
  });

  test('DigitsFormatter accepts Devanagari digits', () {
    const formatter = DigitsFormatter();
    TextEditingValue format(String text) =>
        formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));
    expect(format('१७०').text, '170');
    expect(format('1a7-0').text, '170');
    expect(format('175').text, '175');
  });
}
