// Niyah — riprogramma tutte le notifiche locali partendo dal database.
// Nome dell'azione in FlutterFlow: rescheduleAllNotifications
// Parametri:
//   settingsJson (JSON)  impostazioni da App State, es.
//       {"language": "it", "timezone": "Europe/Rome",
//        "quietHours": {"enabled": true, "start": "22:30", "end": "07:00", "mode": "skip"},
//        "pausedUntil": null,
//        "prayer": {"lat": 41.9, "lng": 12.5, "method": "muslim_world_league", "madhab": "shafi", "offsets": {}}}
//   stringsJson  (JSON)  testi localizzati nella lingua attiva (vedi flutterflow/README.md)
//   forceAll     (bool)  true = cancella e riprogramma tutto (es. dopo un cambio
//                        del permesso "orario esatto")
// Restituisce (JSON): {"scheduled": n, "cancelled": n, "pending": n,
//   "overBudget": [ids], "mutedByQuietHours": [ids], "windowEnd": iso|null, "exact": bool}
//
// Chiamarla: all'avvio, al ritorno in primo piano, dopo ogni modifica di un
// promemoria, della lingua, della posizione, delle impostazioni di preghiera,
// del "Non disturbare" e della pausa. È idempotente: chiamarla due volte non
// crea duplicati.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:timezone/timezone.dart' as tz;

import '/custom_code/actions/niyah_core.dart' as core;
import '/custom_code/actions/niyah_runtime.dart';

Future<dynamic> rescheduleAllNotifications(
  dynamic settingsJson,
  dynamic stringsJson,
  bool forceAll,
) {
  final rt = NiyahRuntime.instance;
  return rt.serialized(() async {
    await rt.ensurePlugin();
    final settings = (settingsJson is Map) ? settingsJson : <String, dynamic>{};
    final lang = (settings['language'] as String?) ?? 'it';
    final loc = await rt.location(settings['timezone'] as String?);
    final now = tz.TZDateTime.now(loc);
    final db = await rt.database();

    // Un cambio di fuso orario (viaggio) impone di ricalcolare tutto.
    final lastTz = await rt.meta('last_timezone');
    if (lastTz != null && lastTz != loc.name) forceAll = true;

    // Modalità di consegna su Android: esatta solo con il permesso concesso.
    final exact = rt.isIos || (await rt.android?.canScheduleExactNotifications() ?? false);
    final lastExact = await rt.meta('last_exact_mode');
    if (lastExact != null && lastExact != '$exact') forceAll = true;

    // 1. Promemoria (fonte di verità)
    final rows = await db.rawQuery(core.NiyahSql.activeReminders);
    final reminders = rows.map(core.Reminder.fromRow).toList();

    // 2. Testi dei modelli nella lingua attiva
    final tpl = await db.rawQuery(core.NiyahSql.templateTexts, [lang]);
    final templateTexts = {
      for (final r in tpl) r['template_id'] as String: core.TextPair(r['title'] as String, r['body'] as String),
    };

    // 3. Orari di preghiera dalla cache (calcolati e salvati se mancano)
    final prayerSettings = core.PrayerSettings.fromJson(settings['prayer']);
    final prayerDays = <core.LocalDate, core.DayPrayerTimes>{};
    final needsPrayer = reminders.any((r) => r.enabled && r.kind == core.ReminderKind.prayer);
    if (prayerSettings != null && needsPrayer) {
      final hash = prayerSettings.hash(loc.name);
      final today = core.LocalDate.of(now);
      final days = core.computePrayerDays(today, 16, prayerSettings, loc);
      final batch = db.batch();
      for (final d in days) {
        prayerDays[d.date] = d;
        batch.insert('prayer_cache', d.toRow(hash), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    // 4. Contenuti idonei (solo se servono)
    final contentTypes = {
      for (final r in reminders)
        if (r.enabled && r.contentType != null) r.contentType!,
    };
    final candidates = <core.ContentCandidate>[];
    if (contentTypes.isNotEmpty) {
      final cRows = await db.rawQuery(core.NiyahSql.contentCandidates(contentTypes.length), [lang, ...contentTypes]);
      candidates.addAll(cRows.map(core.NiyahSql.candidateFromRow));
    }
    final recent = (await db.rawQuery(core.NiyahSql.recentContent)).map((r) => r['content_id'] as String).toList();

    // 5. Notifiche già in attesa nell'OS
    if (forceAll) await rt.plugin.cancelAll();
    final pending = await rt.plugin.pendingNotificationRequests();

    // 6. Piano
    final planner = core.NotificationPlanner(
      location: loc,
      settings: core.PlannerSettings(
        budget: rt.budget,
        quietHours: core.QuietHours.fromJson(settings['quietHours']),
        pausedUntil: DateTime.tryParse((settings['pausedUntil'] as String?) ?? '')?.toUtc(),
        recentContentIds: recent,
      ),
      strings: core.NotificationStrings.fromJson(stringsJson),
      templateTexts: templateTexts,
      prayerTimes: (d) => prayerDays[d],
      contentCandidates: candidates,
    );
    final plan = planner.plan(
      reminders,
      now,
      existing: [
        for (final p in pending) core.ExistingNotification(p.id, title: p.title, body: p.body, payload: p.payload),
      ],
    );
    final diff = plan.diff(pending.map((p) => p.id));

    // 7. Applica la differenza
    for (final id in diff.toCancel) {
      await rt.plugin.cancel(id: id);
    }
    var scheduled = 0;
    for (final n in diff.toSchedule) {
      try {
        await _schedule(rt, n, exact);
        scheduled++;
      } catch (_) {
        // Un errore su una notifica non deve bloccare le altre.
      }
    }

    // 8. Contenuti scelti: evitano ripetizioni nei prossimi giri.
    if (plan.newlyPickedContentIds.isNotEmpty) {
      final stamp = DateTime.now().toUtc().toIso8601String();
      final batch = db.batch();
      for (final id in plan.newlyPickedContentIds) {
        batch.insert('recent_content', {'content_id': id, 'shown_at': stamp},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }
    await rt.setMeta('last_timezone', loc.name);
    await rt.setMeta('last_exact_mode', '$exact');
    await rt.setMeta('last_reschedule_at', DateTime.now().toUtc().toIso8601String());

    return {
      'scheduled': scheduled,
      'cancelled': diff.toCancel.length,
      'pending': plan.notifications.length,
      'overBudget': plan.overBudgetReminderIds,
      'mutedByQuietHours': plan.mutedByQuietHours,
      'windowEnd': plan.windowEnd?.toIso8601String(),
      'exact': exact,
    };
  });
}

Future<void> _schedule(NiyahRuntime rt, core.PlannedNotification n, bool exact) async {
  // iOS non permette di nascondere il testo di una singola notifica sul blocco
  // schermo: per i promemoria privati si mostra il testo neutro e il testo
  // completo si apre nell'app toccando la notifica.
  final usePublicText = rt.isIos && n.isPrivate;
  final title = usePublicText ? n.publicTitle : n.title;
  final body = usePublicText ? n.publicBody : n.body;

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      n.channel,
      rt.channelNames[n.channel] ?? n.channel,
      importance: n.channel == core.NiyahChannels.prayer ? Importance.high : Importance.defaultImportance,
      priority: n.channel == core.NiyahChannels.prayer ? Priority.high : Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(n.body),
      // Su Android il blocco schermo mostra solo "contenuto nascosto".
      visibility: n.isPrivate ? NotificationVisibility.private : NotificationVisibility.public,
      category: n.channel == core.NiyahChannels.prayer ? AndroidNotificationCategory.reminder : null,
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: n.channel),
  );

  await rt.plugin.zonedSchedule(
    id: n.id,
    title: title,
    body: body,
    scheduledDate: n.fireAt,
    notificationDetails: details,
    androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    payload: n.payload,
    matchDateTimeComponents: switch (n.repeat) {
      core.RepeatKind.daily => DateTimeComponents.time,
      core.RepeatKind.weekly => DateTimeComponents.dayOfWeekAndTime,
      core.RepeatKind.none => null,
    },
  );
}
