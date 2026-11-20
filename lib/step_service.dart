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

/// The installed app, for update checks.
class AppInfo {
  const AppInfo({
    required this.version,
    required this.versionCode,
    required this.abis,
    this.canInstallUpdates = true,
  });

  /// Version name, e.g. "1.2.0".
  final String version;
  final int versionCode;

  /// Supported CPU ABIs, most preferred first, e.g. [arm64-v8a, armeabi-v7a].
  final List<String> abis;

  /// "Install unknown apps" is allowed for Footnote, so Android won't ask before an update.
  final bool canInstallUpdates;
}

/// What happened when handing a downloaded update to Android's installer.
enum InstallResult {
  /// The installer is open.
  started,

  /// The file doesn't match its SHA-256 from update.json.
  badChecksum,

  /// The file is gone (e.g. the cache was cleared).
  missing,

  /// Nothing on the phone can install APKs.
  noInstaller,
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

  static Future<AppInfo> getAppInfo() async {
    final map = await _methods.invokeMapMethod<String, Object?>('getAppInfo') ?? const {};
    return AppInfo(
      version: map['version'] as String? ?? '0.0.0',
      versionCode: map['versionCode'] as int? ?? 0,
      abis: (map['abis'] as List?)?.cast<String>() ?? const <String>[],
      canInstallUpdates: map['canInstallUpdates'] as bool? ?? true,
    );
  }

  /// Folder that downloaded updates go in. The installer can only be given files from here.
  static Future<String> getUpdateDir() async => await _methods.invokeMethod<String>('getUpdateDir') ?? '';

  /// Checks the APK at [path] against [sha256] and opens Android's installer for it.
  static Future<InstallResult> installUpdate(String path, String sha256) async {
    final result = await _methods.invokeMethod<String>('installUpdate', {'path': path, 'sha256': sha256});
    return InstallResult.values.asNameMap()[result] ?? InstallResult.missing;
  }

  /// The update the user was last offered on launch, and when.
  static Future<({String? version, DateTime? at})> getUpdatePrompt() async {
    final map = await _methods.invokeMapMethod<String, Object?>('getUpdatePrompt') ?? const {};
    final at = map['at'] as int?;
    return (version: map['version'] as String?, at: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at));
  }

  /// Remembers that the user was just offered [version].
  static Future<void> setUpdatePrompt(String version) => _methods.invokeMethod('setUpdatePrompt', {'version': version});

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
