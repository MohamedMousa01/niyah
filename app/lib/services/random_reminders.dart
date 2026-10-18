// Notifiche random: brevi inviti a rinnovare l'intenzione in momenti casuali
// della giornata. Non stanno nel database: si rigenerano a ogni
// riprogrammazione, sempre uguali per la stessa giornata, così riprogrammare
// non crea duplicati.

import 'dart:math';

import 'package:niyah_core/niyah_core.dart' as core;

class RandomReminders {
  RandomReminders._();

  /// Fascia in cui possono arrivare.
  static const windowStart = core.LocalTime(9, 0);
  static const windowEnd = core.LocalTime(21, 0);
  static const perDay = 3;

  /// Giorni programmati in anticipo: pochi, per lasciare spazio agli altri
  /// promemoria nel limite di notifiche in attesa (iOS: 60).
  static const days = 7;

  static final _updatedAt = DateTime.utc(2026, 1, 1);

  /// Un promemoria "una volta" per ogni notifica random dei prossimi [days]
  /// giorni, a partire da [today]. Ogni giornata ha [perDay] orari, uno per
  /// ciascuna parte della fascia, e testi presi a caso da [texts].
  static List<core.Reminder> forDays(core.LocalDate today, List<core.TextPair> texts) {
    if (texts.isEmpty) return const [];
    final start = windowStart.minutesOfDay;
    final slot = (windowEnd.minutesOfDay - start) ~/ perDay;
    final out = <core.Reminder>[];
    for (var i = 0; i < days; i++) {
      final d = today.addDays(i);
      final rnd = Random(core.stableHash('random|$d'));
      int? lastText;
      for (var n = 0; n < perDay; n++) {
        final minute = start + slot * n + rnd.nextInt(slot);
        var t = rnd.nextInt(texts.length);
        // Due inviti di fila non hanno lo stesso testo.
        if (t == lastText && texts.length > 1) t = (t + 1) % texts.length;
        lastText = t;
        out.add(core.Reminder(
          id: 'random|$d|$n',
          kind: core.ReminderKind.template,
          title: texts[t].title,
          body: texts[t].body,
          scheduleType: core.ScheduleType.once,
          time: core.LocalTime(minute ~/ 60, minute % 60),
          startDate: d,
          channel: core.NiyahChannels.niyyah,
          syncPolicy: 'local_only',
          updatedAt: _updatedAt,
        ));
      }
    }
    return out;
  }
}
