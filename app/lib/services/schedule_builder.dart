// Costruisce il piano delle notifiche dal database (architettura §6).
// Nessuna chiamata al sistema operativo: la applica NotificationService.

import 'package:niyah_core/niyah_core.dart' as core;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

import 'random_reminders.dart';

class ScheduleInput {
  const ScheduleInput({
    required this.language,
    required this.location,
    required this.strings,
    required this.budget,
    this.quietHours = const core.QuietHours(),
    this.pausedUntil,
    this.prayer,
    this.randomTexts = const [],
  });

  final String language;
  final tz.Location location;
  final core.NotificationStrings strings;
  final int budget;
  final core.QuietHours quietHours;
  final DateTime? pausedUntil;
  final core.PrayerSettings? prayer;

  /// Testi delle notifiche random (vuoto = notifiche random spente).
  final List<core.TextPair> randomTexts;
}

class ScheduleBuilder {
  ScheduleBuilder(this.db);

  final Database db;

  /// Giorni di orari di preghiera calcolati a ogni riprogrammazione.
  static const prayerDays = 16;

  Future<core.SchedulePlan> build(
    ScheduleInput input,
    tz.TZDateTime now, {
    List<core.ExistingNotification> existing = const [],
  }) async {
    final reminders = (await db.rawQuery(core.NiyahSql.activeReminders)).map(core.Reminder.fromRow).toList()
      ..addAll(RandomReminders.forDays(core.LocalDate.of(now), input.randomTexts));

    final tpl = await db.rawQuery(core.NiyahSql.templateTexts, [input.language]);
    final templateTexts = {
      for (final r in tpl) r['template_id'] as String: core.TextPair(r['title'] as String, r['body'] as String),
    };

    final prayerDays = <core.LocalDate, core.DayPrayerTimes>{};
    final prayer = input.prayer;
    if (prayer != null && reminders.any((r) => r.enabled && r.kind == core.ReminderKind.prayer)) {
      final hash = prayer.hash(input.location.name);
      final days = core.computePrayerDays(core.LocalDate.of(now), ScheduleBuilder.prayerDays, prayer, input.location);
      final batch = db.batch();
      for (final d in days) {
        prayerDays[d.date] = d;
        batch.insert('prayer_cache', d.toRow(hash), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    final contentTypes = {
      for (final r in reminders)
        if (r.enabled && r.contentType != null) r.contentType!,
    };
    final candidates = <core.ContentCandidate>[];
    if (contentTypes.isNotEmpty) {
      final rows = await db.rawQuery(core.NiyahSql.contentCandidates(contentTypes.length), [input.language, ...contentTypes]);
      candidates.addAll(rows.map(core.NiyahSql.candidateFromRow));
    }
    final recent = (await db.rawQuery(core.NiyahSql.recentContent)).map((r) => r['content_id'] as String).toList();

    final planner = core.NotificationPlanner(
      location: input.location,
      settings: core.PlannerSettings(
        budget: input.budget,
        quietHours: input.quietHours,
        pausedUntil: input.pausedUntil,
        recentContentIds: recent,
      ),
      strings: input.strings,
      templateTexts: templateTexts,
      prayerTimes: (d) => prayerDays[d],
      contentCandidates: candidates,
    );
    return planner.plan(reminders, now, existing: existing);
  }

  /// I contenuti appena scelti non si ripetono nei prossimi giri.
  Future<void> rememberPicked(List<String> contentIds, DateTime at) async {
    if (contentIds.isEmpty) return;
    final stamp = at.toUtc().toIso8601String();
    final batch = db.batch();
    for (final id in contentIds) {
      batch.insert('recent_content', {'content_id': id, 'shown_at': stamp}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
