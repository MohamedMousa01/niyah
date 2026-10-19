import 'package:niyah_core/niyah_core.dart' as core;

import '../../notifications/schedule_inputs.dart';
import '../repositories.dart';
import 'niyah_database.dart';
import 'schedule_codec.dart';

/// What the notification engine needs from the database for one reschedule.
class ScheduleInput {
  /// Planner-ready: enabled, not deleted, expanded with [core.expandReminders]
  /// (ids like "abc:fajr" / "abc:wd"; map back with [core.baseReminderId]).
  final List<core.Reminder> reminders;

  /// Template texts in the requested language (English where missing).
  final Map<String, core.TextPair> templateTexts;

  const ScheduleInput(this.reminders, this.templateTexts);

  /// Whether the planner needs prayer times (any prayer-relative reminder).
  bool get needsPrayerTimes => reminders.any((r) => r.scheduleType == core.ScheduleType.prayer);
}

/// Reads the reminders straight from SQLite for [core.NotificationPlanner]:
/// the [ScheduleInputs] of the notification engine on a device.
class ScheduleSource extends ScheduleInputs {
  ScheduleSource(this._db, this._settings);

  final NiyahDatabase _db;
  final SettingsStore _settings;

  Future<ScheduleInput> load(String languageCode) async =>
      ScheduleInput(await reminders(), await templateTexts(languageCode));

  @override
  Future<List<core.Reminder>> plannerReminders() => reminders();

  @override
  bool get prayerDuringQuiet => _settings.prayerDuringQuiet;

  /// Active reminders, expanded with the settings' wake-up and bed times.
  Future<List<core.Reminder>> reminders() async {
    final rows = await _db.db.rawQuery(core.NiyahSql.activeReminders);
    final quietForPrayer = _settings.prayerDuringQuiet ? 0 : 1;
    return core.expandReminders([
      for (final row in rows)
        if (row['enabled'] == 1)
          core.Reminder.fromRow(row['kind'] == 'prayer' ? {...row, 'respects_quiet_hours': quietForPrayer} : row),
    ], dayAnchors(_settings.anchors));
  }

  /// Template texts in [languageCode], falling back to English.
  @override
  Future<Map<String, core.TextPair>> templateTexts(String languageCode) async {
    const fallback = 'en';
    final rows = await _db.db.query('template_i18n', where: 'lang IN (?, ?)', whereArgs: [languageCode, fallback]);
    // English first, then the requested language on top.
    return {
      for (final lang in [fallback, languageCode])
        for (final r in rows)
          if (r['lang'] == lang) r['template_id'] as String: core.TextPair(r['title'] as String, r['body'] as String),
    };
  }
}
