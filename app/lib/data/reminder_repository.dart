// Promemoria dell'utente (tabella `reminders`). Ogni modifica va seguita da
// una riprogrammazione delle notifiche (AppController lo fa da solo).

import 'package:niyah_core/niyah_core.dart' as core;
import 'package:sqflite/sqflite.dart';

import 'catalog_repository.dart';

class ReminderRepository {
  ReminderRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Database db;
  final DateTime Function() _clock;

  String _nowIso() => _clock().toUtc().toIso8601String();

  /// Promemoria nati da un modello, per id del modello.
  Future<Map<String, core.Reminder>> templateReminders() async {
    final rows = await db.query('reminders', where: "kind = 'template' AND deleted = 0");
    return {
      for (final r in rows.map(core.Reminder.fromRow))
        if (r.templateId != null) r.templateId!: r,
    };
  }

  /// Attiva o disattiva il promemoria di un modello. Alla prima attivazione
  /// il promemoria nasce con la pianificazione proposta dal modello.
  Future<void> setTemplateEnabled(TemplateItem t, bool enabled, {required String deviceId}) async {
    final now = _nowIso();
    final updated = await db.update(
      'reminders',
      {'enabled': enabled ? 1 : 0, 'updated_at': now, 'device_id': deviceId},
      where: "kind = 'template' AND template_id = ? AND deleted = 0",
      whereArgs: [t.id],
    );
    if (updated > 0 || !enabled) return;
    final s = t.schedule;
    await db.insert('reminders', {
      'id': core.generateUuidV4(),
      'kind': 'template',
      'template_id': t.id,
      'category_id': t.categoryId,
      'content_type': t.contentType,
      'schedule_type': s.type.name,
      'time': s.time?.toString(),
      'window_start': s.windowStart?.toString(),
      'window_end': s.windowEnd?.toString(),
      'times_per_day': s.timesPerDay,
      'days_mask': s.daysMask,
      'start_date': core.LocalDate.of(_clock()).toString(),
      'enabled': 1,
      'channel': t.channel,
      'sync_policy': 'cloud',
      'device_id': deviceId,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Nuovo orario e nuovi giorni di un promemoria a orario fisso. Tutti i
  /// giorni = "ogni giorno"; altrimenti settimanale sui giorni scelti.
  Future<void> updateFixedSchedule(String reminderId, core.LocalTime time, int daysMask, {required String deviceId}) async {
    if (daysMask & core.DaysMask.all == 0) {
      throw ArgumentError.value(daysMask, 'daysMask', 'almeno un giorno');
    }
    final all = daysMask & core.DaysMask.all == core.DaysMask.all;
    await db.update(
      'reminders',
      {
        'schedule_type': all ? 'daily' : 'weekly',
        'time': time.toString(),
        'days_mask': daysMask & core.DaysMask.all,
        'updated_at': _nowIso(),
        'device_id': deviceId,
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }
}
