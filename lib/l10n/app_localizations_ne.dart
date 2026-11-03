// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appName => 'Footnote';

  @override
  String get tagline => 'हरेक पाइलाको टिपोट।';

  @override
  String get today => 'आज';

  @override
  String get yesterday => 'हिजो';

  @override
  String get history => 'इतिहास';

  @override
  String get steps => 'पाइला';

  @override
  String stepsToGo(String steps) {
    return '$steps पाइला बाँकी';
  }

  @override
  String get goalReached => 'लक्ष्य पूरा भयो! 🎉';

  @override
  String goalChip(String goal) {
    return 'लक्ष्य: $goal';
  }

  @override
  String get distance => 'दूरी';

  @override
  String get calories => 'क्यालोरी';

  @override
  String get last7Days => 'पछिल्ला ७ दिन';

  @override
  String get language => 'भाषा';

  @override
  String get languageSystem => 'फोनको भाषा';

  @override
  String get batteryTitle => 'ब्याकग्राउन्डमा गन्ती जारी राख्नुहोस्';

  @override
  String get batteryBody =>
      'एप बन्द हुँदा पनि पाइला गन्ती नरोकियोस् भन्नका लागि यस एपको ब्याट्री प्रयोगलाई प्रतिबन्धरहित बनाउनुहोस्।';

  @override
  String get notNow => 'अहिले होइन';

  @override
  String get setUnrestricted => 'प्रतिबन्ध हटाउनुहोस्';

  @override
  String get dailyGoal => 'दैनिक लक्ष्य';

  @override
  String get customGoal => 'आफ्नै लक्ष्य';

  @override
  String get save => 'सेभ गर्नुहोस्';

  @override
  String get yourDetails => 'तपाईंको विवरण';

  @override
  String get yourDetailsBody =>
      'दूरी र क्यालोरी अनुमान गर्न प्रयोग हुन्छ। यो जानकारी तपाईंको फोनमै रहन्छ।';

  @override
  String get metric => 'मेट्रिक';

  @override
  String get imperial => 'इम्पेरियल';

  @override
  String get height => 'उचाइ';

  @override
  String get weight => 'तौल';

  @override
  String get unitCm => 'से.मि.';

  @override
  String get unitFt => 'फिट';

  @override
  String get unitIn => 'इन्च';

  @override
  String get unitKg => 'के.जी.';

  @override
  String get unitLb => 'पाउन्ड';

  @override
  String heightRangeCm(String min, String max) {
    return '$min–$max से.मि.';
  }

  @override
  String heightRangeFtIn(
    String minFt,
    String minIn,
    String maxFt,
    String maxIn,
  ) {
    return '$minFt फिट $minIn इन्च – $maxFt फिट $maxIn इन्च';
  }

  @override
  String weightRangeKg(String min, String max) {
    return '$min–$max के.जी.';
  }

  @override
  String weightRangeLb(String min, String max) {
    return '$min–$max पाउन्ड';
  }

  @override
  String heightCm(String value) {
    return '$value से.मि.';
  }

  @override
  String heightFtIn(String feet, String inches) {
    return '$feet फिट $inches इन्च';
  }

  @override
  String weightKg(String value) {
    return '$value के.जी.';
  }

  @override
  String weightLb(String value) {
    return '$value पाउन्ड';
  }

  @override
  String distanceKm(String value) {
    return '$value कि.मि.';
  }

  @override
  String distanceMi(String value) {
    return '$value माइल';
  }

  @override
  String energyKcal(String value) {
    return '$value क्यालोरी';
  }

  @override
  String energyKj(String value) {
    return '$value कि.जु.';
  }

  @override
  String get kilometres => 'किलोमिटर';

  @override
  String get miles => 'माइल';

  @override
  String get kilocalories => 'किलोक्यालोरी';

  @override
  String get kilojoules => 'किलोजुल';

  @override
  String get distanceSheetBody =>
      'एप, विजेट र सूचनामा दूरी कसरी देखाउने, रोज्नुहोस्।';

  @override
  String get caloriesSheetBody =>
      'एप, विजेट र सूचनामा खर्च भएको क्यालोरी कसरी देखाउने, रोज्नुहोस्।';

  @override
  String estimatedFromHeight(String height) {
    return 'तपाईंको उचाइ ($height) अनुसार अनुमान गरिएको।';
  }

  @override
  String estimatedFromWeight(String weight) {
    return 'तपाईंको तौल ($weight) अनुसार अनुमान गरिएको।';
  }

  @override
  String get edit => 'बदल्नुहोस्';

  @override
  String get range7 => '७ दिन';

  @override
  String get range30 => '३० दिन';

  @override
  String get totalSteps => 'जम्मा पाइला';

  @override
  String get dailyAvg => 'दैनिक औसत';

  @override
  String get bestDay => 'उत्कृष्ट दिन';

  @override
  String get goalMet => 'लक्ष्य पूरा';

  @override
  String get avgDistance => 'औसत दूरी';

  @override
  String get allDays => 'सबै दिन';

  @override
  String get noStepsYet =>
      'अहिलेसम्म कुनै पाइला रेकर्ड भएको छैन। हिँड्न सुरु गर्नुहोस्!';

  @override
  String get noSensorTitle => 'पाइला सेन्सर छैन';

  @override
  String get noSensorBody =>
      'यो फोनमा पाइला गन्ने हार्डवेयर सेन्सर छैन, त्यसैले पाइला रेकर्ड गर्न सकिँदैन।';

  @override
  String get permissionTitle => 'आफ्ना पाइला गन्नुहोस्';

  @override
  String get permissionBody =>
      'एप बन्द हुँदा पनि Footnote ले ब्याकग्राउन्डमा पाइला गन्न सकोस् भनेर शारीरिक गतिविधिको अनुमति दिनुहोस्।';

  @override
  String get activityBlockedBody =>
      'शारीरिक गतिविधिको अनुमति बन्द छ। सेटिङ खोल्नुहोस्, अनुमतिहरूमा जानुहोस् र शारीरिक गतिविधिलाई अनुमति दिनुहोस्।';

  @override
  String get openSettings => 'सेटिङ खोल्नुहोस्';

  @override
  String get allow => 'अनुमति दिनुहोस्';

  @override
  String get allowed => 'अनुमति दिइएको छ';

  @override
  String get continueButton => 'अगाडि बढ्नुहोस्';

  @override
  String get skip => 'छोड्नुहोस्';

  @override
  String get getStarted => 'सुरु गरौं';

  @override
  String get welcomeBody =>
      'Footnote ले तपाईंको फोनको पाइला सेन्सरबाट ब्याकग्राउन्डमै पाइला गन्छ। खाता चाहिँदैन, र तपाईंको डाटा फोनमै रहन्छ।';

  @override
  String get activityTitle => 'शारीरिक गतिविधिको अनुमति दिनुहोस्';

  @override
  String get activityBody =>
      'कुनै पनि एपले पाइला सेन्सर पढ्नुअघि Android ले तपाईंसँग अनुमति माग्छ। Footnote ले यसलाई पाइला गन्न मात्र प्रयोग गर्छ।';

  @override
  String get notificationTitle => 'स्थायी सूचना देखाउनुहोस्';

  @override
  String get notificationBody =>
      'गन्ती चलिरहँदा Footnote ले आजका पाइलासहितको एउटा सूचना राखिरहन्छ। एप बन्द हुँदा पनि गन्ती जारी राख्न Android लाई यो चाहिन्छ।';

  @override
  String get notificationBlockedBody =>
      'Footnote का सूचनाहरू बन्द छन्। सेटिङ खोलेर सूचनाहरू अन गर्नुहोस्।';

  @override
  String get allowNotifications => 'सूचनाको अनुमति दिनुहोस्';

  @override
  String get notificationsAllowed => 'सूचनाहरू अन छन्';

  @override
  String notificationPreviewTitle(String steps) {
    return 'आज $steps पाइला';
  }

  @override
  String notificationPreviewText(String distance, String energy, String goal) {
    return '$distance · $energy · लक्ष्य $goal';
  }

  @override
  String get detailsTitle => 'तपाईंको बारेमा';

  @override
  String get detailsBody =>
      'उचाइ र तौलले दूरी र क्यालोरीको अनुमान अझ सही बनाउँछ। यो जानकारी तपाईंको फोनबाहिर जाँदैन।';

  @override
  String get startCounting => 'गन्ती सुरु गर्नुहोस्';

  @override
  String stepOfTotal(String current, String total) {
    return '$total मध्ये $current चरण';
  }

  @override
  String get updateTitle => 'नयाँ संस्करण उपलब्ध छ';

  @override
  String updateBody(String version, String current) {
    return 'संस्करण $version डाउनलोड गर्न तयार छ। तपाईंसँग $current छ।';
  }

  @override
  String get whatsNew => 'के नयाँ छ';

  @override
  String get later => 'पछि';

  @override
  String get download => 'डाउनलोड गर्नुहोस्';
}
