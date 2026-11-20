import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

  /// App name; not translated.
  ///
  /// In en, this message translates to:
  /// **'Footnote'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Every step, noted.'**
  String get tagline;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Unit after a step count, e.g. 6,240 steps.
  ///
  /// In en, this message translates to:
  /// **'steps'**
  String get steps;

  /// No description provided for @stepsToGo.
  ///
  /// In en, this message translates to:
  /// **'{steps} to go'**
  String stepsToGo(String steps);

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached! 🎉'**
  String get goalReached;

  /// No description provided for @goalChip.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String goalChip(String goal);

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Follow the language the phone is set to.
  ///
  /// In en, this message translates to:
  /// **'Phone\'s language'**
  String get languageSystem;

  /// No description provided for @batteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep counting in the background'**
  String get batteryTitle;

  /// No description provided for @batteryBody.
  ///
  /// In en, this message translates to:
  /// **'Set battery usage to Unrestricted so Android doesn\'t pause step tracking when the app is closed.'**
  String get batteryBody;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @setUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Set Unrestricted'**
  String get setUnrestricted;

  /// No description provided for @dailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get dailyGoal;

  /// No description provided for @customGoal.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customGoal;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @yourDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get yourDetails;

  /// No description provided for @yourDetailsBody.
  ///
  /// In en, this message translates to:
  /// **'Used to estimate distance and calories. Stays on your phone.'**
  String get yourDetailsBody;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitFt.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFt;

  /// No description provided for @unitIn.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get unitIn;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitLb.
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get unitLb;

  /// No description provided for @heightRangeCm.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} cm'**
  String heightRangeCm(String min, String max);

  /// No description provided for @heightRangeFtIn.
  ///
  /// In en, this message translates to:
  /// **'{minFt} ft {minIn} in – {maxFt} ft {maxIn} in'**
  String heightRangeFtIn(
    String minFt,
    String minIn,
    String maxFt,
    String maxIn,
  );

  /// No description provided for @weightRangeKg.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} kg'**
  String weightRangeKg(String min, String max);

  /// No description provided for @weightRangeLb.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} lb'**
  String weightRangeLb(String min, String max);

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'{value} cm'**
  String heightCm(String value);

  /// No description provided for @heightFtIn.
  ///
  /// In en, this message translates to:
  /// **'{feet} ft {inches} in'**
  String heightFtIn(String feet, String inches);

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String weightKg(String value);

  /// No description provided for @weightLb.
  ///
  /// In en, this message translates to:
  /// **'{value} lb'**
  String weightLb(String value);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String distanceKm(String value);

  /// No description provided for @distanceMi.
  ///
  /// In en, this message translates to:
  /// **'{value} mi'**
  String distanceMi(String value);

  /// No description provided for @energyKcal.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal'**
  String energyKcal(String value);

  /// No description provided for @energyKj.
  ///
  /// In en, this message translates to:
  /// **'{value} kJ'**
  String energyKj(String value);

  /// No description provided for @kilometres.
  ///
  /// In en, this message translates to:
  /// **'Kilometres'**
  String get kilometres;

  /// No description provided for @miles.
  ///
  /// In en, this message translates to:
  /// **'Miles'**
  String get miles;

  /// No description provided for @kilocalories.
  ///
  /// In en, this message translates to:
  /// **'Kilocalories'**
  String get kilocalories;

  /// No description provided for @kilojoules.
  ///
  /// In en, this message translates to:
  /// **'Kilojoules'**
  String get kilojoules;

  /// No description provided for @distanceSheetBody.
  ///
  /// In en, this message translates to:
  /// **'How distance is shown in the app, widgets and notification.'**
  String get distanceSheetBody;

  /// No description provided for @caloriesSheetBody.
  ///
  /// In en, this message translates to:
  /// **'How calories burned are shown in the app, widgets and notification.'**
  String get caloriesSheetBody;

  /// No description provided for @estimatedFromHeight.
  ///
  /// In en, this message translates to:
  /// **'Estimated from your height, {height}.'**
  String estimatedFromHeight(String height);

  /// No description provided for @estimatedFromWeight.
  ///
  /// In en, this message translates to:
  /// **'Estimated from your weight, {weight}.'**
  String estimatedFromWeight(String weight);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Last 7 days, short.
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get range7;

  /// Last 30 days, short.
  ///
  /// In en, this message translates to:
  /// **'30D'**
  String get range30;

  /// No description provided for @totalSteps.
  ///
  /// In en, this message translates to:
  /// **'Total steps'**
  String get totalSteps;

  /// No description provided for @dailyAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily avg'**
  String get dailyAvg;

  /// No description provided for @bestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get bestDay;

  /// Number of days the goal was reached.
  ///
  /// In en, this message translates to:
  /// **'Goal met'**
  String get goalMet;

  /// No description provided for @avgDistance.
  ///
  /// In en, this message translates to:
  /// **'Avg distance'**
  String get avgDistance;

  /// No description provided for @allDays.
  ///
  /// In en, this message translates to:
  /// **'All days'**
  String get allDays;

  /// No description provided for @noStepsYet.
  ///
  /// In en, this message translates to:
  /// **'No steps recorded yet. Start walking!'**
  String get noStepsYet;

  /// No description provided for @noSensorTitle.
  ///
  /// In en, this message translates to:
  /// **'No step sensor'**
  String get noSensorTitle;

  /// No description provided for @noSensorBody.
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t have a hardware step counter, so steps can\'t be recorded.'**
  String get noSensorBody;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Count your steps'**
  String get permissionTitle;

  /// No description provided for @permissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow access to physical activity so Footnote can count your steps in the background, even when the app is closed.'**
  String get permissionBody;

  /// No description provided for @activityBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Physical activity access is turned off. Open settings, tap Permissions and allow Physical activity.'**
  String get activityBlockedBody;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Footnote counts your steps in the background with your phone\'s step sensor. No account needed, and your data stays on your phone.'**
  String get welcomeBody;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow physical activity'**
  String get activityTitle;

  /// No description provided for @activityBody.
  ///
  /// In en, this message translates to:
  /// **'Android asks before any app can read your step sensor. Footnote only uses it to count your steps.'**
  String get activityBody;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Show a permanent notification'**
  String get notificationTitle;

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'While it counts, Footnote keeps a notification with today\'s steps. Android needs it to keep counting when the app is closed.'**
  String get notificationBody;

  /// No description provided for @notificationBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Footnote. Open settings and turn them on.'**
  String get notificationBlockedBody;

  /// No description provided for @allowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// No description provided for @notificationsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on'**
  String get notificationsAllowed;

  /// Same as the real notification's title.
  ///
  /// In en, this message translates to:
  /// **'{steps} steps today'**
  String notificationPreviewTitle(String steps);

  /// No description provided for @notificationPreviewText.
  ///
  /// In en, this message translates to:
  /// **'{distance} · {energy} · Goal {goal}'**
  String notificationPreviewText(String distance, String energy, String goal);

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get detailsTitle;

  /// No description provided for @detailsBody.
  ///
  /// In en, this message translates to:
  /// **'Your height and weight make distance and calorie estimates more accurate. They never leave your phone.'**
  String get detailsBody;

  /// No description provided for @startCounting.
  ///
  /// In en, this message translates to:
  /// **'Start counting'**
  String get startCounting;

  /// Onboarding progress, read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOfTotal(String current, String total);

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready to download. You have {current}.'**
  String updateBody(String version, String current);

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whatsNew;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateSize.
  ///
  /// In en, this message translates to:
  /// **'Download size: {size}'**
  String updateSize(String size);

  /// No description provided for @installPermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to let Footnote install apps. It\'s only used for updates.'**
  String get installPermissionHint;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {received} of {total}'**
  String updateDownloading(String received, String total);

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Downloaded. Tap Install to finish updating.'**
  String get updateReady;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the update. Check your internet connection and try again.'**
  String get updateFailed;

  /// No description provided for @updateDamaged.
  ///
  /// In en, this message translates to:
  /// **'The download was damaged. Try again.'**
  String get updateDamaged;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionNumber(String version);

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version.'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Check your internet connection and try again.'**
  String get updateCheckFailed;

  /// File size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMb(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
