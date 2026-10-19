import 'package:niyah_core/niyah_core.dart';

import '../data/defaults.dart';

/// Everything [LocalNotificationService] needs to build the OS schedule.
///
/// The data layer implements it (SQLite in Phase 4). Getters with a body
/// return the temporary defaults from `lib/data/defaults.dart`; override them
/// once the matching setting exists.
abstract class ScheduleInputs {
  /// Active, non-deleted reminders, **already expanded**: multi-prayer and
  /// wake/bed reminders arrive as plain core reminders with stable ids.
  Future<List<Reminder>> plannerReminders();

  /// Template texts in [lang] (template id → title/body).
  Future<Map<String, TextPair>> templateTexts(String lang);

  /// Prayer reminders may ring during quiet hours.
  bool get prayerDuringQuiet;

  QuietHours get quietHours => const QuietHours();

  /// Global pause (UTC instant); null = not paused.
  DateTime? get pausedUntil => null;

  /// Where and how prayer times are computed.
  PrayerSettings get prayerSettings => const PrayerSettings(
        latitude: Defaults.prayerLat,
        longitude: Defaults.prayerLng,
        method: Defaults.prayerMethod,
        madhab: Defaults.asrMadhab,
      );
}

/// Fixed inputs held in memory: tests and previews.
class InMemoryScheduleInputs extends ScheduleInputs {
  InMemoryScheduleInputs({
    List<Reminder> reminders = const [],
    Map<String, Map<String, TextPair>> templates = const {},
    this.prayerDuringQuiet = Defaults.prayerDuringQuiet,
    this.quietHours = const QuietHours(),
    this.pausedUntil,
  })  : reminders = [...reminders],
        templates = {...templates};

  List<Reminder> reminders;

  /// Language code → template id → texts.
  Map<String, Map<String, TextPair>> templates;

  @override
  bool prayerDuringQuiet;

  @override
  QuietHours quietHours;

  @override
  DateTime? pausedUntil;

  @override
  Future<List<Reminder>> plannerReminders() async =>
      [for (final r in reminders) if (r.enabled && !r.deleted) r];

  @override
  Future<Map<String, TextPair>> templateTexts(String lang) async => templates[lang] ?? const {};
}
