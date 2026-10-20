import 'package:flutter/foundation.dart';
import 'package:niyah_core/niyah_core.dart' as core show PrayerSettings, defaultMethodForCountry;

import 'models.dart';

/// Source of truth for the user's reminders. Listeners are notified after
/// every change; `main.dart` wires that to [NotificationService.reschedule].
abstract class ReminderRepository extends ChangeNotifier {
  /// Loads the reminders. Call once before use.
  Future<void> init();

  /// Every non-deleted reminder, prayer reminder included.
  List<ReminderItem> get all;

  ReminderItem? byId(String id);

  /// The reminder created from [templateId], if the user added it.
  ReminderItem? byTemplate(String templateId);

  /// The single "Prayer reminders" reminder (created with defaults if missing).
  ReminderItem get prayer;

  /// Creates or updates. A new personal reminder gets its id from [newId].
  Future<void> save(ReminderItem reminder);

  Future<void> setEnabled(String id, bool enabled);

  Future<void> delete(String id);

  String newId();
}

/// Ready-made moments, in the current language.
abstract class TemplateRepository {
  Future<void> init();

  List<TemplateItem> templates(String languageCode);

  TemplateItem? byId(String id, String languageCode);
}

/// Today's prayer times for the location and method in [SettingsStore].
/// Listeners are notified when those settings change.
abstract class PrayerRepository extends ChangeNotifier {
  Future<void> init();

  /// Null while no prayer location is set.
  PrayerDay? get today;

  /// The next prayer after [now] today, or null if Isha has passed (or no
  /// location is set).
  (Prayer, LocalTime)? nextPrayer(DateTime now) {
    final day = today;
    if (day == null) return null;
    final minutes = now.hour * 60 + now.minute;
    for (final e in day.times.entries) {
      if (e.value.minutesOfDay > minutes) return (e.key, e.value);
    }
    return null;
  }
}

/// The offline list of cities in the bundled database (GeoNames).
abstract class CityRepository {
  /// Cities whose name (or one of its other names, e.g. "Milano") starts
  /// with [query], biggest first. Accents and case are ignored.
  Future<List<PrayerLocation>> search(String query, {int limit = 20});

  /// The city closest to the coordinates, or null if none is near.
  Future<PrayerLocation?> nearest(double latitude, double longitude);
}

/// Result of asking the phone where it is.
sealed class PositionResult {
  const PositionResult();
}

class PositionFound extends PositionResult {
  final double latitude;
  final double longitude;
  const PositionFound(this.latitude, this.longitude);
}

/// Why no position was found.
enum PositionProblem {
  /// Location services are switched off on the phone.
  serviceOff,

  /// The user said no (the app may ask again).
  denied,

  /// The user said "never": only the system settings can change it.
  deniedForever,

  /// Anything else (timeout, no fix, unsupported platform).
  unavailable,
}

class PositionFailed extends PositionResult {
  final PositionProblem problem;
  const PositionFailed(this.problem);
}

/// One-time position for the prayer location (never tracked or sent).
abstract class LocationService {
  /// Asks for permission if needed, then reads a coarse position once.
  Future<PositionResult> currentPosition();

  /// Opens the app's page in the system settings (after "never").
  Future<void> openAppSettings();
}

/// Small settings, persisted on the device. Every setter notifies the
/// listeners; `main.dart` reschedules the notifications on each change.
abstract class SettingsStore extends ChangeNotifier {
  Future<void> init();

  AnchorTimes get anchors;
  Future<void> setAnchors(AnchorTimes value);

  /// Prayer reminders may ring during quiet hours.
  bool get prayerDuringQuiet;
  Future<void> setPrayerDuringQuiet(bool value);

  /// Light or dark look of the app (independent of the phone's setting).
  AppTheme get theme;
  Future<void> setTheme(AppTheme value);

  /// App language ('en', 'it'); null = the phone's language.
  String? get languageCode;
  Future<void> setLanguageCode(String? value);

  /// Where prayer times are computed; null until the user sets it.
  PrayerLocation? get location;
  Future<void> setLocation(PrayerLocation? value);

  /// Calculation method chosen by the user (an adhan `CalculationMethod`
  /// name); null = the one suggested for the location's country ([method]).
  String? get methodChoice;
  Future<void> setMethodChoice(String? value);

  /// Asr: 'shafi' (standard) or 'hanafi'.
  String get madhab;
  Future<void> setMadhab(String value);

  QuietHours get quietHours;
  Future<void> setQuietHours(QuietHours value);

  /// Every reminder stays silent until this UTC instant; null = not paused.
  DateTime? get pausedUntil;
  Future<void> setPausedUntil(DateTime? value);

  /// The pause end stored for "until I turn them back on".
  static final pausedForever = DateTime.utc(9999);

  /// The method in use: the user's choice, or the usual one in the
  /// location's country.
  String get method => methodChoice ?? core.defaultMethodForCountry(location?.country);

  /// Input of the prayer-time calculation; null while no location is set.
  core.PrayerSettings? get prayerSettings {
    final l = location;
    if (l == null) return null;
    return core.PrayerSettings(latitude: l.latitude, longitude: l.longitude, method: method, madhab: madhab);
  }

  /// Whether reminders are paused at [now].
  bool isPaused(DateTime now) {
    final until = pausedUntil;
    return until != null && until.isAfter(now.toUtc());
  }
}

/// Local notifications. Every method is safe to call on any platform.
abstract class NotificationService {
  Future<void> init();

  /// Rebuilds the OS schedule from the reminders. Serialized and idempotent.
  Future<void> reschedule();

  /// Asks for permission once, in context (first add / first switch on).
  /// Returns whether notifications are allowed.
  Future<bool> ensurePermission();

  /// Asks for exact alarms (Android 12+) when prayer reminders are switched on.
  /// Without it, notifications may arrive a few minutes late. Always true on iOS.
  Future<bool> ensureExactAlarms();

  /// Whether the OS currently lets the app show notifications.
  Future<bool> areEnabled();

  /// Opens the app's notification settings in the OS.
  Future<void> openSystemSettings();

  /// Payload of the notification that opened the app, if any.
  ValueListenable<String?> get tappedPayload;

  /// Returns [tappedPayload] and clears it, so a tap is handled once.
  String? takeTappedPayload();
}
