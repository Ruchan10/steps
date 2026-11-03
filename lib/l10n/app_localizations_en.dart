// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Footnote';

  @override
  String get tagline => 'Every step, noted.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get history => 'History';

  @override
  String get steps => 'steps';

  @override
  String stepsToGo(String steps) {
    return '$steps to go';
  }

  @override
  String get goalReached => 'Goal reached! 🎉';

  @override
  String goalChip(String goal) {
    return 'Goal: $goal';
  }

  @override
  String get distance => 'Distance';

  @override
  String get calories => 'Calories';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Phone\'s language';

  @override
  String get batteryTitle => 'Keep counting in the background';

  @override
  String get batteryBody =>
      'Set battery usage to Unrestricted so Android doesn\'t pause step tracking when the app is closed.';

  @override
  String get notNow => 'Not now';

  @override
  String get setUnrestricted => 'Set Unrestricted';

  @override
  String get dailyGoal => 'Daily goal';

  @override
  String get customGoal => 'Custom';

  @override
  String get save => 'Save';

  @override
  String get yourDetails => 'Your details';

  @override
  String get yourDetailsBody =>
      'Used to estimate distance and calories. Stays on your phone.';

  @override
  String get metric => 'Metric';

  @override
  String get imperial => 'Imperial';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get unitCm => 'cm';

  @override
  String get unitFt => 'ft';

  @override
  String get unitIn => 'in';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String heightRangeCm(String min, String max) {
    return '$min–$max cm';
  }

  @override
  String heightRangeFtIn(
    String minFt,
    String minIn,
    String maxFt,
    String maxIn,
  ) {
    return '$minFt ft $minIn in – $maxFt ft $maxIn in';
  }

  @override
  String weightRangeKg(String min, String max) {
    return '$min–$max kg';
  }

  @override
  String weightRangeLb(String min, String max) {
    return '$min–$max lb';
  }

  @override
  String heightCm(String value) {
    return '$value cm';
  }

  @override
  String heightFtIn(String feet, String inches) {
    return '$feet ft $inches in';
  }

  @override
  String weightKg(String value) {
    return '$value kg';
  }

  @override
  String weightLb(String value) {
    return '$value lb';
  }

  @override
  String distanceKm(String value) {
    return '$value km';
  }

  @override
  String distanceMi(String value) {
    return '$value mi';
  }

  @override
  String energyKcal(String value) {
    return '$value kcal';
  }

  @override
  String energyKj(String value) {
    return '$value kJ';
  }

  @override
  String get kilometres => 'Kilometres';

  @override
  String get miles => 'Miles';

  @override
  String get kilocalories => 'Kilocalories';

  @override
  String get kilojoules => 'Kilojoules';

  @override
  String get distanceSheetBody =>
      'How distance is shown in the app, widgets and notification.';

  @override
  String get caloriesSheetBody =>
      'How calories burned are shown in the app, widgets and notification.';

  @override
  String estimatedFromHeight(String height) {
    return 'Estimated from your height, $height.';
  }

  @override
  String estimatedFromWeight(String weight) {
    return 'Estimated from your weight, $weight.';
  }

  @override
  String get edit => 'Edit';

  @override
  String get range7 => '7D';

  @override
  String get range30 => '30D';

  @override
  String get totalSteps => 'Total steps';

  @override
  String get dailyAvg => 'Daily avg';

  @override
  String get bestDay => 'Best day';

  @override
  String get goalMet => 'Goal met';

  @override
  String get avgDistance => 'Avg distance';

  @override
  String get allDays => 'All days';

  @override
  String get noStepsYet => 'No steps recorded yet. Start walking!';

  @override
  String get noSensorTitle => 'No step sensor';

  @override
  String get noSensorBody =>
      'This device doesn\'t have a hardware step counter, so steps can\'t be recorded.';

  @override
  String get permissionTitle => 'Count your steps';

  @override
  String get permissionBody =>
      'Allow access to physical activity so Footnote can count your steps in the background, even when the app is closed.';

  @override
  String get activityBlockedBody =>
      'Physical activity access is turned off. Open settings, tap Permissions and allow Physical activity.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get allow => 'Allow';

  @override
  String get allowed => 'Allowed';

  @override
  String get continueButton => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get started';

  @override
  String get welcomeBody =>
      'Footnote counts your steps in the background with your phone\'s step sensor. No account needed, and your data stays on your phone.';

  @override
  String get activityTitle => 'Allow physical activity';

  @override
  String get activityBody =>
      'Android asks before any app can read your step sensor. Footnote only uses it to count your steps.';

  @override
  String get notificationTitle => 'Show a permanent notification';

  @override
  String get notificationBody =>
      'While it counts, Footnote keeps a notification with today\'s steps. Android needs it to keep counting when the app is closed.';

  @override
  String get notificationBlockedBody =>
      'Notifications are turned off for Footnote. Open settings and turn them on.';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get notificationsAllowed => 'Notifications are on';

  @override
  String notificationPreviewTitle(String steps) {
    return '$steps steps today';
  }

  @override
  String notificationPreviewText(String distance, String energy, String goal) {
    return '$distance · $energy · Goal $goal';
  }

  @override
  String get detailsTitle => 'About you';

  @override
  String get detailsBody =>
      'Your height and weight make distance and calorie estimates more accurate. They never leave your phone.';

  @override
  String get startCounting => 'Start counting';

  @override
  String stepOfTotal(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get updateTitle => 'Update available';

  @override
  String updateBody(String version, String current) {
    return 'Version $version is ready to download. You have $current.';
  }

  @override
  String get whatsNew => 'What\'s new';

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';
}
