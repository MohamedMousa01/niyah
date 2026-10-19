import 'dart:convert';

import 'package:niyah_core/niyah_core.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const strings = NotificationStrings(
  prayerNames: {
    Prayer.fajr: 'Fajr',
    Prayer.dhuhr: 'Dhuhr',
    Prayer.asr: 'Asr',
    Prayer.maghrib: 'Maghrib',
    Prayer.isha: 'Isha',
  },
  prayerAtTime: "È l'ora di {prayer}",
  prayerBefore: '{prayer} tra {minutes} minuti',
  quranTitle: "Qur'an",
  hadithTitle: 'Hadith',
  dhikrTitle: 'Dhikr',
  tapToRead: 'Tocca per leggere',
  refreshTitle: 'Niyah',
  refreshBody: 'Apri Niyah per continuare a ricevere i promemoria.',
  privateTitle: 'Niyah',
  privateBody: 'Ricorda la tua intenzione',
);

late tz.Location rome;

Reminder daily(String id, String time, {ReminderKind kind = ReminderKind.personal, int days = DaysMask.all, String title = 'Rinnova la tua intenzione', String? updated, LocalDate? start, LocalDate? end, DateTime? pausedUntil, ScheduleType type = ScheduleType.daily}) =>
    Reminder(
      id: id,
      kind: kind,
      title: title,
      body: 'Testo scritto da me',
      scheduleType: type,
      time: LocalTime.tryParse(time),
      daysMask: days,
      startDate: start ?? const LocalDate(2026, 1, 1),
      endDate: end,
      pausedUntil: pausedUntil,
      updatedAt: DateTime.parse(updated ?? '2026-10-01T10:00:00Z'),
    );

Reminder prayerReminder(Prayer p, {int offset = 0}) => Reminder(
      id: 'prayer_${p.name}',
      kind: ReminderKind.prayer,
      scheduleType: ScheduleType.prayer,
      prayer: p,
      offsetMin: offset,
      startDate: const LocalDate(2026, 1, 1),
      respectsQuietHours: false,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

Reminder contentReminder(String id, {String type = 'hadith', int times = 2}) => Reminder(
      id: id,
      kind: ReminderKind.content,
      contentType: type,
      scheduleType: ScheduleType.window,
      windowStart: const LocalTime(9, 0),
      windowEnd: const LocalTime(21, 0),
      timesPerDay: times,
      startDate: const LocalDate(2026, 1, 1),
      channel: type == 'quran' ? NiyahChannels.quran : NiyahChannels.hadith,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

/// Contenuti FITTIZI di test: identificativi e segnaposto, nessun testo religioso.
List<ContentCandidate> fakeContent(int n, {String type = 'hadith'}) => [
      for (var i = 0; i < n; i++)
        ContentCandidate(id: '$type-$i', type: type, reference: 'REF-$i', text: 'TESTO-SEGNAPOSTO-$i'),
    ];

NotificationPlanner planner({int budget = PlannerSettings.iosBudget, QuietHours quiet = const QuietHours(), DateTime? pausedUntil, List<String> recent = const [], List<ContentCandidate> content = const [], PrayerTimesProvider? prayers, int horizon = 14}) =>
    NotificationPlanner(
      location: rome,
      settings: PlannerSettings(budget: budget, horizonDays: horizon, quietHours: quiet, pausedUntil: pausedUntil, recentContentIds: recent),
      strings: strings,
      prayerTimes: prayers,
      contentCandidates: content,
    );

tz.TZDateTime at(int y, int m, int d, int h, [int mi = 0]) => tz.TZDateTime(rome, y, m, d, h, mi);

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    rome = tz.getLocation('Europe/Rome');
  });

  group('basi', () {
    test('LocalTime e QuietHours che attraversano la mezzanotte', () {
      const q = QuietHours(enabled: true, start: LocalTime(22, 30), end: LocalTime(7, 0));
      expect(q.contains(const LocalTime(23, 0)), isTrue);
      expect(q.contains(const LocalTime(3, 0)), isTrue);
      expect(q.contains(const LocalTime(7, 0)), isFalse);
      expect(q.contains(const LocalTime(12, 0)), isFalse);
      expect(const QuietHours(enabled: false).contains(const LocalTime(23, 0)), isFalse);
      expect(LocalTime.tryParse('25:00'), isNull);
      expect(LocalTime.tryParse('7:05').toString(), '07:05');
    });

    test('stableHash è positivo e deterministico', () {
      expect(stableHash('abc'), stableHash('abc'));
      expect(stableHash('abc'), isNot(stableHash('abd')));
      expect(stableHash('x') > 0 && stableHash('x') <= 0x7FFFFFFF, isTrue);
    });

    test('validazione dell\'editor', () {
      expect(daily('a', '08:00').validate(), isEmpty);
      final noTime = Reminder(id: 'b', kind: ReminderKind.personal, title: 't', scheduleType: ScheduleType.daily, startDate: const LocalDate(2026, 1, 1), updatedAt: DateTime.utc(2026));
      expect(noTime.validate(), contains('error_time_required'));
      expect(daily('c', '08:00', type: ScheduleType.weekly, days: 0).validate(), contains('error_days_required'));
      expect(daily('d', '08:00', start: const LocalDate(2026, 5, 2), end: const LocalDate(2026, 5, 1)).validate(), contains('error_end_before_start'));
    });

    test('promemoria "peccato che sto combattendo": sempre locale e nascosto sul blocco schermo', () {
      final r = Reminder.fromRow({
        'id': 's1',
        'kind': 'struggle',
        'title': 'Il mio titolo',
        'body': 'Il mio testo',
        'schedule_type': 'daily',
        'time': '21:00',
        'start_date': '2026-01-01',
        'sync_policy': 'cloud', // anche se il record dice cloud
        'updated_at': '2026-10-01T10:00:00Z',
      });
      expect(r.syncPolicy, 'local_only');
      expect(r.hideOnLockScreen, isTrue);
      final plan = planner().plan([r], at(2026, 10, 13, 10));
      final n = plan.notifications.single;
      expect(n.title, 'Il mio titolo'); // testo dell'utente intatto
      expect(n.body, 'Il mio testo');
      expect(n.publicTitle, 'Niyah');
      expect(n.publicBody, 'Ricorda la tua intenzione');
      expect(n.channel, NiyahChannels.personal);
    });
  });

  group('ripetute (caso A)', () {
    test('giornaliero = 1 sola notifica ripetuta, nessun rinfresco', () {
      final plan = planner().plan([daily('a', '08:00')], at(2026, 10, 13, 10));
      expect(plan.notifications, hasLength(1));
      final n = plan.notifications.single;
      expect(n.repeat, RepeatKind.daily);
      expect(n.fireAt, at(2026, 10, 14, 8)); // le 8 di oggi sono passate
      expect(plan.windowEnd, isNull);
    });

    test('settimanale lunedì e giovedì = 2 notifiche settimanali', () {
      const monThu = 1 | (1 << 3);
      final plan = planner().plan([daily('w', '19:30', type: ScheduleType.weekly, days: monThu)], at(2026, 10, 13, 10)); // martedì
      expect(plan.notifications.map((n) => n.repeat).toSet(), {RepeatKind.weekly});
      expect(plan.notifications.map((n) => n.fireAt.weekday).toSet(), {DateTime.monday, DateTime.thursday});
      expect(plan.notifications.first.fireAt, at(2026, 10, 15, 19, 30));
    });

    test('id stabili: riprogrammare il giorno dopo non cambia nulla', () {
      final rs = [daily('a', '08:00'), daily('b', '13:00')];
      final p1 = planner().plan(rs, at(2026, 10, 13, 10));
      final p2 = planner().plan(rs, at(2026, 10, 14, 18));
      final diff = p2.diff(p1.notifications.map((n) => n.id));
      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, isEmpty);
    });

    test('modificare un promemoria cancella la vecchia notifica e ne crea una nuova (niente duplicati)', () {
      final p1 = planner().plan([daily('a', '08:00')], at(2026, 10, 13, 10));
      final p2 = planner().plan([daily('a', '08:00', title: 'Nuovo titolo')], at(2026, 10, 13, 10));
      final diff = p2.diff(p1.notifications.map((n) => n.id));
      expect(diff.toCancel, [p1.notifications.single.id]);
      expect(diff.toSchedule.single.title, 'Nuovo titolo');
    });

    test('ora legale: un promemoria alle 08:00 resta alle 08:00 locali', () {
      final plan = planner().plan([daily('a', '08:00')], at(2026, 10, 24, 12)); // cambio ora il 25/10
      final n = plan.notifications.single;
      expect(n.fireAt.hour, 8);
      expect(n.fireAt.timeZoneOffset, const Duration(hours: 1)); // già CET il 25/10
    });

    test('budget iOS: 70 promemoria giornalieri → 60 programmati, 10 segnalati', () {
      final rs = [for (var i = 0; i < 70; i++) daily('r$i', '${(6 + i % 15).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}')];
      final plan = planner().plan(rs, at(2026, 10, 13, 5));
      expect(plan.notifications.length, 60);
      expect(plan.overBudgetReminderIds, hasLength(10));
    });
  });

  group('singole (caso B)', () {
    PrayerTimesProvider romePrayers() {
      const s = PrayerSettings(latitude: 41.9028, longitude: 12.4964);
      return (d) => computePrayerTimes(d, s, rome);
    }

    test('preghiere: finestra mobile entro il budget, in ordine, con notifica di rinfresco', () {
      final rs = [for (final p in Prayer.values) prayerReminder(p, offset: p == Prayer.fajr ? 15 : 0)];
      final now = at(2026, 10, 13, 10);
      final plan = planner(prayers: romePrayers()).plan(rs, now);
      expect(plan.notifications.length, lessThanOrEqualTo(PlannerSettings.iosBudget));
      expect(plan.notifications.every((n) => n.fireAt.isAfter(now)), isTrue);
      final refresh = plan.notifications.where((n) => n.reminderId == '_refresh').toList();
      expect(refresh, hasLength(1));
      expect(plan.windowEnd, isNotNull);
      expect(refresh.single.fireAt.isBefore(plan.windowEnd!), isTrue);
      // 59 preghiere = quasi 12 giorni coperti da sole
      final prayers = plan.notifications.where((n) => n.reminderId != '_refresh').toList();
      expect(prayers.length, 59);
      final fajr = prayers.firstWhere((n) => n.reminderId == 'prayer_fajr');
      expect(fajr.body, 'Fajr tra 15 minuti');
      final dhuhr = prayers.firstWhere((n) => n.reminderId == 'prayer_dhuhr');
      expect(dhuhr.body, "È l'ora di Dhuhr");
    });

    test('le ripetute hanno la precedenza e le singole riempiono il resto', () {
      final rs = [daily('a', '08:00'), daily('b', '21:00'), for (final p in Prayer.values) prayerReminder(p)];
      final plan = planner(prayers: romePrayers()).plan(rs, at(2026, 10, 13, 10));
      expect(plan.notifications.where((n) => n.repeat != RepeatKind.none), hasLength(2));
      expect(plan.notifications.length, PlannerSettings.iosBudget);
    });

    test('Android: budget più ampio, finestra completa senza tagli', () {
      final rs = [for (final p in Prayer.values) prayerReminder(p)];
      final plan = planner(budget: PlannerSettings.androidBudget, prayers: romePrayers()).plan(rs, at(2026, 10, 13, 10));
      final prayers = plan.notifications.where((n) => n.reminderId != '_refresh');
      expect(prayers.length, inInclusiveRange(14 * 5, 15 * 5));
    });

    test('data di fine vicina → singole fino alla fine, nessun rinfresco', () {
      final plan = planner().plan([daily('a', '08:00', end: const LocalDate(2026, 10, 16))], at(2026, 10, 13, 10));
      expect(plan.notifications.map((n) => n.fireAt.day).toList(), [14, 15, 16]);
      expect(plan.notifications.every((n) => n.repeat == RepeatKind.none), isTrue);
      expect(plan.notifications.any((n) => n.reminderId == '_refresh'), isFalse);
    });

    test('una tantum', () {
      final r = daily('o', '18:00', type: ScheduleType.once, start: const LocalDate(2026, 10, 20));
      final plan = planner().plan([r], at(2026, 10, 13, 10));
      expect(plan.notifications.single.fireAt, at(2026, 10, 20, 18));
    });
  });

  group('non disturbare e pausa', () {
    const quietSkip = QuietHours(enabled: true, start: LocalTime(22, 30), end: LocalTime(7, 0));
    const quietShift = QuietHours(enabled: true, start: LocalTime(22, 30), end: LocalTime(7, 0), mode: QuietMode.shift);

    test('salta: un promemoria alle 23:00 è silenziato e segnalato', () {
      final plan = planner(quiet: quietSkip).plan([daily('n', '23:00')], at(2026, 10, 13, 10));
      expect(plan.notifications, isEmpty);
      expect(plan.mutedByQuietHours, ['n']);
    });

    test('sposta: un promemoria alle 23:00 arriva alle 07:00', () {
      final plan = planner(quiet: quietShift).plan([daily('n', '23:00')], at(2026, 10, 13, 10));
      expect(plan.notifications.single.fireAt.hour, 7);
    });

    test('le preghiere possono ignorare il non disturbare', () {
      final r = prayerReminder(Prayer.isha);
      final plan = planner(quiet: const QuietHours(enabled: true, start: LocalTime(18, 0), end: LocalTime(23, 59)), prayers: (d) => computePrayerTimes(d, const PrayerSettings(latitude: 41.9, longitude: 12.5), rome))
          .plan([r], at(2026, 10, 13, 10));
      expect(plan.notifications.where((n) => n.reminderId == r.id), isNotEmpty);
    });

    test('pausa globale: niente prima della fine, poi i promemoria ripartono da soli', () {
      final pause = at(2026, 10, 15, 12).toUtc();
      final plan = planner(pausedUntil: pause).plan([daily('a', '08:00')], at(2026, 10, 13, 10));
      final singles = plan.notifications.where((n) => n.reminderId == 'a').toList();
      expect(singles.first.fireAt, at(2026, 10, 16, 8));
      expect(singles.every((n) => n.repeat == RepeatKind.none), isTrue);
      expect(plan.notifications.any((n) => n.reminderId == '_refresh'), isTrue);
    });

    test('promemoria disattivato o eliminato: nessuna notifica, configurazione intatta', () {
      final off = Reminder.fromRow({'id': 'x', 'kind': 'personal', 'title': 't', 'schedule_type': 'daily', 'time': '08:00', 'start_date': '2026-01-01', 'enabled': 0});
      expect(planner().plan([off], at(2026, 10, 13, 10)).notifications, isEmpty);
      expect(off.time.toString(), '08:00');
    });
  });

  group('contenuti Corano/Hadith', () {
    test('nessuna ripetizione ravvicinata e nessun contenuto recente', () {
      final content = fakeContent(40);
      final recent = ['hadith-0', 'hadith-1', 'hadith-2'];
      final plan = planner(content: content, recent: recent).plan([contentReminder('c')], at(2026, 10, 13, 6));
      final ids = plan.notifications.where((n) => n.contentId != null).map((n) => n.contentId!).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.any(recent.contains), isFalse);
      expect(plan.newlyPickedContentIds, ids);
    });

    test('il contenuto già programmato non cambia a ogni riprogrammazione', () {
      final content = fakeContent(40);
      final now = at(2026, 10, 13, 6);
      final p1 = planner(content: content).plan([contentReminder('c')], now);
      final existing = [for (final n in p1.notifications) ExistingNotification(n.id, title: n.title, body: n.body, payload: n.payload)];
      // la seconda volta i contenuti già scelti risultano "recenti"
      final p2 = planner(content: content, recent: p1.newlyPickedContentIds.reversed.toList()).plan([contentReminder('c')], now, existing: existing);
      final diff = p2.diff(existing.map((e) => e.id));
      expect(diff.toSchedule, isEmpty);
      expect(diff.toCancel, isEmpty);
    });

    test('testo lungo: mai tagliato, si invita ad aprirlo', () {
      final long = ContentCandidate(id: 'q-1', type: 'quran', reference: 'REF', text: 'x' * 1000);
      final plan = planner(content: [long]).plan([contentReminder('c', type: 'quran', times: 1)], at(2026, 10, 13, 6));
      final n = plan.notifications.firstWhere((n) => n.contentId != null);
      expect(n.body, 'Tocca per leggere');
      expect(n.title, "Qur'an · REF");
      expect(jsonDecode(n.payload)['c'], 'q-1');
    });

    test('senza contenuti idonei non parte nessuna notifica vuota', () {
      final plan = planner(content: fakeContent(5, type: 'quran')).plan([contentReminder('c', type: 'hadith')], at(2026, 10, 13, 6));
      expect(plan.notifications.where((n) => n.reminderId == 'c'), isEmpty);
    });
  });

  group('orari di preghiera', () {
    // Riferimenti indipendenti (libreria Python "astral", NOAA):
    // Roma 2026-03-21: alba 06:12:07, mezzogiorno solare 12:17:17, tramonto 18:22:54 (CET)
    // Roma 2026-03-30: alba 06:56:43, mezzogiorno 13:14:35, tramonto 19:32:55 (CEST)
    // Mecca 2026-01-15: alba 07:01:11, mezzogiorno 12:29:55, tramonto 17:59:05
    void near(tz.TZDateTime t, int h, int m, {int tol = 3}) {
      final diff = (t.hour * 60 + t.minute) - (h * 60 + m);
      expect(diff.abs(), lessThanOrEqualTo(tol), reason: '$t vs $h:$m');
    }

    test('Roma, equinozio', () {
      final d = computePrayerTimes(const LocalDate(2026, 3, 21), const PrayerSettings(latitude: 41.9028, longitude: 12.4964), rome);
      near(d.sunrise, 6, 12);
      near(d.times[Prayer.dhuhr]!, 12, 18); // MWL aggiunge 1 minuto al mezzogiorno
      near(d.times[Prayer.maghrib]!, 18, 23);
    });

    test('Roma, dopo il cambio dell\'ora legale', () {
      final d = computePrayerTimes(const LocalDate(2026, 3, 30), const PrayerSettings(latitude: 41.9028, longitude: 12.4964), rome);
      expect(d.times[Prayer.dhuhr]!.timeZoneOffset, const Duration(hours: 2));
      near(d.times[Prayer.dhuhr]!, 13, 15);
      near(d.times[Prayer.maghrib]!, 19, 33);
    });

    test('Mecca con Umm al-Qura: Isha 90 minuti dopo Maghrib', () {
      final riyadh = tz.getLocation('Asia/Riyadh');
      final d = computePrayerTimes(const LocalDate(2026, 1, 15), PrayerSettings(latitude: 21.4225, longitude: 39.8262, method: defaultMethodForCountry('SA')), riyadh);
      near(d.sunrise, 7, 1);
      near(d.times[Prayer.maghrib]!, 17, 59);
      expect(d.times[Prayer.isha]!.difference(d.times[Prayer.maghrib]!).inMinutes, 90);
    });

    test('ordine corretto, Asr hanafi più tardi, alta latitudine gestita', () {
      final oslo = tz.getLocation('Europe/Oslo');
      for (final date in [const LocalDate(2026, 6, 21), const LocalDate(2026, 12, 21)]) {
        final d = computePrayerTimes(date, const PrayerSettings(latitude: 59.91, longitude: 10.75), oslo);
        final ts = [d.times[Prayer.fajr]!, d.sunrise, d.times[Prayer.dhuhr]!, d.times[Prayer.asr]!, d.times[Prayer.maghrib]!, d.times[Prayer.isha]!];
        for (var i = 1; i < ts.length; i++) {
          expect(ts[i].isAfter(ts[i - 1]), isTrue, reason: '$date: ${ts[i - 1]} → ${ts[i]}');
        }
      }
      final shafi = computePrayerTimes(const LocalDate(2026, 10, 13), const PrayerSettings(latitude: 41.9, longitude: 12.5), rome);
      final hanafi = computePrayerTimes(const LocalDate(2026, 10, 13), const PrayerSettings(latitude: 41.9, longitude: 12.5, madhab: 'hanafi'), rome);
      expect(hanafi.times[Prayer.asr]!.isAfter(shafi.times[Prayer.asr]!), isTrue);
    });

    test('aggiustamenti manuali e impronta delle impostazioni', () {
      const base = PrayerSettings(latitude: 41.9, longitude: 12.5);
      const plus = PrayerSettings(latitude: 41.9, longitude: 12.5, offsets: {Prayer.isha: 5});
      final a = computePrayerTimes(const LocalDate(2026, 10, 13), base, rome);
      final b = computePrayerTimes(const LocalDate(2026, 10, 13), plus, rome);
      expect(b.times[Prayer.isha]!.difference(a.times[Prayer.isha]!).inMinutes, 5);
      expect(base.hash('Europe/Rome'), isNot(plus.hash('Europe/Rome')));
      expect(base.hash('Europe/Rome'), isNot(base.hash('Europe/Paris')));
    });
  });

  group('merge della sincronizzazione', () {
    final now = DateTime.utc(2026, 10, 13);
    SyncRecord rec(String id, String t, {String dev = 'A', bool del = false, bool localOnly = false}) =>
        SyncRecord(id: id, updatedAt: DateTime.parse(t), deviceId: dev, deleted: del, localOnly: localOnly);

    test('vince la modifica più recente', () {
      final m = mergeRecords([rec('1', '2026-10-10T10:00:00Z')], [rec('1', '2026-10-11T10:00:00Z', dev: 'B')], nowUtc: now);
      expect(m.toLocal.single.deviceId, 'B');
      expect(m.toRemote, isEmpty);
    });

    test('a parità vince il deviceId maggiore, in modo deterministico', () {
      final l = [rec('1', '2026-10-10T10:00:00Z', dev: 'B')];
      final r = [rec('1', '2026-10-10T10:00:00Z', dev: 'A')];
      expect(mergeRecords(l, r, nowUtc: now).toRemote.single.deviceId, 'B');
      expect(mergeRecords(r, l, nowUtc: now).toLocal.single.deviceId, 'B');
    });

    test('record solo da una parte vengono copiati, mai persi', () {
      final m = mergeRecords([rec('L', '2026-10-10T10:00:00Z')], [rec('R', '2026-10-10T10:00:00Z')], nowUtc: now);
      expect(m.toRemote.single.id, 'L');
      expect(m.toLocal.single.id, 'R');
    });

    test('i promemoria privati non vengono mai caricati né sovrascritti', () {
      final m = mergeRecords([rec('s', '2026-10-10T10:00:00Z', localOnly: true)], [], nowUtc: now);
      expect(m.toRemote, isEmpty);
      final m2 = mergeRecords([rec('s', '2026-10-10T10:00:00Z', localOnly: true)], [rec('s', '2026-10-12T10:00:00Z')], nowUtc: now);
      expect(m2.toLocal, isEmpty);
    });

    test('le eliminazioni si propagano e le tombstone scadute vengono ripulite', () {
      final m = mergeRecords([rec('1', '2026-10-12T10:00:00Z', del: true)], [rec('1', '2026-10-10T10:00:00Z')], nowUtc: now);
      expect(m.toRemote.single.deleted, isTrue);
      final old = mergeRecords([rec('2', '2026-08-01T10:00:00Z', del: true)], [rec('2', '2026-08-01T10:00:00Z', del: true)], nowUtc: now);
      expect(old.toPurge, ['2']);
    });
  });

  group('impostazioni (JSON)', () {
    test('QuietHours e PrayerSettings da JSON o stringa', () {
      final q = QuietHours.fromJson('{"enabled": true, "start": "23:00", "end": "06:30", "mode": "shift"}');
      expect(q.enabled, isTrue);
      expect(q.end, const LocalTime(6, 30));
      expect(q.mode, QuietMode.shift);
      expect(QuietHours.fromJson(null).enabled, isFalse);
      final p = PrayerSettings.fromJson({'lat': 45.46, 'lng': 9.19, 'method': 'egyptian', 'offsets': {'isha': 3}})!;
      expect(p.method, 'egyptian');
      expect(p.offsets[Prayer.isha], 3);
      expect(PrayerSettings.fromJson({'method': 'egyptian'}), isNull); // posizione non ancora scelta
    });

    test('NotificationStrings da JSON', () {
      final s = NotificationStrings.fromJson(jsonEncode({
        'prayerNames': {'fajr': 'Fajr'},
        'prayerAtTime': 'a', 'prayerBefore': 'b', 'quranTitle': 'q', 'hadithTitle': 'h', 'dhikrTitle': 'd',
        'tapToRead': 't', 'refreshTitle': 'r', 'refreshBody': 'rb', 'privateTitle': 'p', 'privateBody': 'pb',
      }));
      expect(s.prayerNames[Prayer.fajr], 'Fajr');
      expect(s.prayerNames[Prayer.isha], 'isha');
    });

    test('UUID v4', () {
      final a = generateUuidV4(), b = generateUuidV4();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(b));
    });
  });
}
