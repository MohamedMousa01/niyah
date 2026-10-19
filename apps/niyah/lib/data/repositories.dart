import 'package:flutter/foundation.dart';

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

/// Today's prayer times for the current location settings.
abstract class PrayerRepository extends ChangeNotifier {
  Future<void> init();

  PrayerDay? get today;

  /// e.g. "Milan · Muslim World League".
  String get locationLabel;

  /// The next prayer after [now] today, or null if Isha has passed.
  (Prayer, LocalTime)? nextPrayer(DateTime now);
}

/// Small settings, persisted on the device.
abstract class SettingsStore extends ChangeNotifier {
  Future<void> init();

  AnchorTimes get anchors;
  Future<void> setAnchors(AnchorTimes value);

  /// Prayer reminders may ring during quiet hours.
  bool get prayerDuringQuiet;
  Future<void> setPrayerDuringQuiet(bool value);
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
}
