import 'package:flutter/services.dart';

import 'metrics.dart';

class TrackingStatus {
  const TrackingStatus({
    required this.sensorAvailable,
    required this.permissionGranted,
    required this.notificationsAllowed,
    required this.batteryUnrestricted,
    required this.goal,
    required this.profile,
    required this.profileSet,
    required this.onboarded,
    this.language,
    this.accentColor,
  });

  final bool sensorAvailable;

  /// Physical activity permission, needed to read the step counter.
  final bool permissionGranted;

  /// The tracking notification can be shown.
  final bool notificationsAllowed;

  /// App is set to "Unrestricted" battery usage, so Android won't stop tracking.
  final bool batteryUnrestricted;
  final int goal;
  final BodyProfile profile;

  /// The user has entered their height and weight (otherwise [profile] holds defaults).
  final bool profileSet;

  /// Finished the first-run setup.
  final bool onboarded;

  /// "en" or "ne", or null to follow the phone's language.
  final String? language;

  /// Wallpaper accent colour on Android 12+, null otherwise.
  final int? accentColor;
}

enum AppPermission { activity, notifications }

enum PermissionResult { granted, denied, blocked }

class DaySteps {
  const DaySteps(this.date, this.steps);

  final DateTime date;
  final int steps;
}

/// Thin wrapper around the native step counter (see android/.../StepCounterService.kt).
class StepService {
  static const _methods = MethodChannel('steps/methods');
  static const _today = EventChannel('steps/today');

  static Future<TrackingStatus> getStatus() async {
    final map = await _methods.invokeMapMethod<String, Object?>('getStatus') ?? const {};
    return TrackingStatus(
      sensorAvailable: map['sensorAvailable'] as bool? ?? false,
      permissionGranted: map['permissionGranted'] as bool? ?? false,
      notificationsAllowed: map['notificationsAllowed'] as bool? ?? false,
      batteryUnrestricted: map['batteryUnrestricted'] as bool? ?? true,
      goal: map['goal'] as int? ?? 10000,
      profile: BodyProfile.fromMap(map['profile'] as Map?),
      profileSet: map['profileSet'] as bool? ?? false,
      onboarded: map['onboarded'] as bool? ?? false,
      language: map['language'] as String?,
      accentColor: map['accentColor'] as int?,
    );
  }

  /// Shows the system permission dialog, unless it's already granted or blocked.
  static Future<PermissionResult> requestPermission(AppPermission permission) async {
    final result = await _methods.invokeMethod<String>('requestPermission', {'permission': permission.name});
    return PermissionResult.values.asNameMap()[result] ?? PermissionResult.denied;
  }

  /// Asks Android to let the app always run in the background.
  /// Completes with the new state once the user returns to the app.
  static Future<bool> requestBatteryUnrestricted() async =>
      await _methods.invokeMethod<bool>('requestBatteryUnrestricted') ?? false;

  /// Installed version name (e.g. "1.2.0") and supported CPU ABIs, most preferred first.
  static Future<({String version, List<String> abis})> getAppInfo() async {
    final map = await _methods.invokeMapMethod<String, Object?>('getAppInfo') ?? const {};
    return (
      version: map['version'] as String? ?? '0.0.0',
      abis: (map['abis'] as List?)?.cast<String>() ?? const <String>[],
    );
  }

  /// Opens [url] in the browser. Returns false if nothing can handle it.
  static Future<bool> openUrl(String url) async =>
      await _methods.invokeMethod<bool>('openUrl', {'url': url}) ?? false;

  static Future<void> openAppSettings() => _methods.invokeMethod('openAppSettings');

  static Future<void> openNotificationSettings() => _methods.invokeMethod('openNotificationSettings');

  static Future<void> setOnboarded() => _methods.invokeMethod('setOnboarded');

  /// "en" or "ne", or null to follow the phone's language. Also used by the widgets and notification.
  static Future<void> setLanguage(String? language) => _methods.invokeMethod('setLanguage', {'language': language});

  static Future<bool> startTracking() async =>
      await _methods.invokeMethod<bool>('startTracking') ?? false;

  static int? _lastToday;

  // One shared platform subscription: a second receiveBroadcastStream() on the
  // same channel would steal the native listener from the first.
  static final Stream<int> _todayShared =
      _today.receiveBroadcastStream().map((e) => _lastToday = e as int);

  /// Emits today's step count immediately (when known) and whenever it changes.
  static Stream<int> todaySteps() async* {
    final last = _lastToday;
    if (last != null) yield last;
    yield* _todayShared;
  }

  static Future<void> setProfile(BodyProfile profile) => _methods.invokeMethod('setProfile', profile.toMap());

  static Future<void> setGoal(int goal) => _methods.invokeMethod('setGoal', {'goal': goal});

  /// Recorded days, newest first.
  static Future<List<DaySteps>> getHistory({int limit = 365}) async {
    final rows = await _methods.invokeListMethod<Map>('getHistory', {'limit': limit}) ?? const [];
    return [
      for (final row in rows) DaySteps(DateTime.parse(row['date'] as String), row['steps'] as int),
    ];
  }
}
