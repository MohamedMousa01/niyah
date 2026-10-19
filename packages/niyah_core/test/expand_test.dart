// Offset con segno, promemoria su più preghiere, promemoria "anchor" e
// expandReminders. Dati FITTIZI: nessun testo religioso.
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
  prayerAfter: '{minutes} minuti dopo {prayer}',
  quranTitle: "Qur'an",
  hadithTitle: 'Hadith',
  dhikrTitle: 'Dhikr',
  tapToRead: 'Tocca per leggere',
  refreshTitle: 'Niyah',
  refreshBody: 'Apri Niyah',
  privateTitle: 'Niyah',
  privateBody: 'Privato',
);

const anchors = DayAnchors(wake: LocalTime(6, 40), wakeWeekend: LocalTime(8, 0), sleep: LocalTime(22, 30));

late tz.Location rome;

tz.TZDateTime at(int y, int m, int d, int h, [int mi = 0]) => tz.TZDateTime(rome, y, m, d, h, mi);

DayPrayerTimes? romePrayers(LocalDate d) => computePrayerTimes(d, const PrayerSettings(latitude: 41.9028, longitude: 12.4964), rome);

NotificationPlanner planner({NotificationStrings s = strings, Map<String, TextPair> texts = const {}, int budget = PlannerSettings.androidBudget}) =>
    NotificationPlanner(
      location: rome,
      settings: PlannerSettings(budget: budget),
      strings: s,
      templateTexts: texts,
      prayerTimes: romePrayers,
    );

Reminder prayerRem(String id, {Prayer? prayer, int? mask, int offset = 10, ReminderKind kind = ReminderKind.prayer, String? templateId}) => Reminder(
      id: id,
      kind: kind,
      templateId: templateId,
      scheduleType: ScheduleType.prayer,
      prayer: prayer,
      prayersMask: mask,
      offsetMin: offset,
      startDate: const LocalDate(2026, 1, 1),
      respectsQuietHours: false,
      updatedAt: DateTime.utc(2026, 10, 1),
    );

Reminder anchorRem(String id, AnchorKind? a, {int days = DaysMask.all, ReminderKind kind = ReminderKind.personal}) => Reminder(
      id: id,
      kind: kind,
      title: 'Titolo',
      body: 'Testo',
      scheduleType: ScheduleType.anchor,
      anchor: a,
      daysMask: days,
      startDate: const LocalDate(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    rome = tz.getLocation('Europe/Rome');
  });

  group('offset con segno', () {
    test('validate accetta −60…120', () {
      for (final ok in [-60, -15, 0, 10, 120]) {
        expect(prayerRem('p', prayer: Prayer.fajr, offset: ok).validate(), isEmpty, reason: '$ok');
      }
      for (final bad in [-61, 121]) {
        expect(prayerRem('p', prayer: Prayer.fajr, offset: bad).validate(), contains('error_prayer_offset'), reason: '$bad');
      }
    });

    test('offset negativo = dopo l\'adhan, con il testo "dopo"', () {
      final now = at(2026, 10, 13, 10);
      final adhan = romePrayers(const LocalDate(2026, 10, 13))!.times[Prayer.dhuhr]!;
      final plan = planner().plan([prayerRem('p', prayer: Prayer.dhuhr, offset: -15)], now);
      final first = plan.notifications.firstWhere((n) => n.reminderId == 'p');
      expect(first.fireAt, adhan.add(const Duration(minutes: 15)));
      expect(first.body, '15 minuti dopo Dhuhr');
    });

    test('offset positivo = prima dell\'adhan; zero = all\'adhan', () {
      final now = at(2026, 10, 13, 10);
      final adhan = romePrayers(const LocalDate(2026, 10, 13))!.times[Prayer.dhuhr]!;
      final before = planner().plan([prayerRem('b', prayer: Prayer.dhuhr, offset: 10)], now).notifications.first;
      expect(before.fireAt, adhan.subtract(const Duration(minutes: 10)));
      expect(before.body, 'Dhuhr tra 10 minuti');
      final atAdhan = planner().plan([prayerRem('z', prayer: Prayer.dhuhr, offset: 0)], now).notifications.first;
      expect(atAdhan.fireAt, adhan);
      expect(atAdhan.body, "È l'ora di Dhuhr");
    });

    test('senza il testo "dopo" si usa quello "all\'adhan", mai minuti negativi', () {
      final s = NotificationStrings.fromJson({
        'prayerAtTime': 'Ora di {prayer}', 'prayerBefore': '{prayer} tra {minutes}', 'quranTitle': 'q', 'hadithTitle': 'h',
        'dhikrTitle': 'd', 'tapToRead': 't', 'refreshTitle': 'r', 'refreshBody': 'r', 'privateTitle': 'p', 'privateBody': 'p',
      });
      expect(s.prayerAfter, isNull);
      final n = planner(s: s).plan([prayerRem('p', prayer: Prayer.dhuhr, offset: -15)], at(2026, 10, 13, 10)).notifications.first;
      expect(n.body, 'Ora di dhuhr');
    });
  });

  group('modello', () {
    test('PrayersMask', () {
      expect(PrayersMask.of(Prayer.values), PrayersMask.all);
      expect(PrayersMask.of({Prayer.fajr, Prayer.asr}), 1 | 4);
      expect(PrayersMask.prayers(1 | 4), [Prayer.fajr, Prayer.asr]);
      expect(PrayersMask.prayers(0), isEmpty);
    });

    test('fromRow legge prayers_mask, anchor e schedule_type anchor', () {
      final p = Reminder.fromRow({'id': 'a', 'kind': 'template', 'schedule_type': 'prayer', 'prayers_mask': 31, 'offset_min': -20, 'start_date': '2026-01-01'});
      expect(p.prayersMask, 31);
      expect(p.offsetMin, -20);
      expect(p.prayers, Prayer.values);
      expect(p.validate(), isEmpty);
      final w = Reminder.fromRow({'id': 'w', 'kind': 'template', 'schedule_type': 'anchor', 'anchor': 'sleep', 'start_date': '2026-01-01'});
      expect(w.scheduleType, ScheduleType.anchor);
      expect(w.anchor, AnchorKind.sleep);
      expect(w.validate(), isEmpty);
    });

    test('la vecchia colonna prayer vale solo se la maschera è null', () {
      expect(prayerRem('a', prayer: Prayer.isha).prayers, [Prayer.isha]);
      expect(prayerRem('a', prayer: Prayer.isha, mask: 1).prayers, [Prayer.fajr]);
      expect(prayerRem('a').validate(), contains('error_prayer_required'));
      expect(prayerRem('a', mask: 0).validate(), contains('error_prayer_required'));
    });

    test('validate degli anchor', () {
      expect(anchorRem('a', AnchorKind.wake).validate(), isEmpty);
      expect(anchorRem('a', null).validate(), contains('error_anchor_required'));
      expect(anchorRem('a', AnchorKind.wake, days: 0).validate(), contains('error_days_required'));
    });

    test('copyWith: senza argomenti copia tutto, con argomenti cambia solo quelli', () {
      final r = Reminder(
        id: 'r', kind: ReminderKind.template, templateId: 't', categoryId: 'c', title: 'T', body: 'B', contentType: 'dhikr',
        scheduleType: ScheduleType.prayer, time: const LocalTime(8, 0), windowStart: const LocalTime(9, 0),
        windowEnd: const LocalTime(21, 0), timesPerDay: 3, daysMask: 31, prayer: Prayer.asr, prayersMask: 5, offsetMin: -20,
        anchor: AnchorKind.sleep, startDate: const LocalDate(2026, 1, 2), endDate: const LocalDate(2026, 12, 31), enabled: false,
        pausedUntil: DateTime.utc(2026, 11), respectsQuietHours: false, hideOnLockScreen: true, channel: NiyahChannels.dhikr,
        syncPolicy: 'local_only', updatedAt: DateTime.utc(2026, 10, 2), deleted: true,
      );
      List<Object?> fields(Reminder x) => [
            x.id, x.kind, x.templateId, x.categoryId, x.title, x.body, x.contentType, x.scheduleType, x.time, x.windowStart,
            x.windowEnd, x.timesPerDay, x.daysMask, x.prayer, x.prayersMask, x.offsetMin, x.anchor, x.startDate, x.endDate,
            x.enabled, x.pausedUntil, x.respectsQuietHours, x.hideOnLockScreen, x.channel, x.syncPolicy, x.updatedAt, x.deleted,
          ];
      expect(fields(r.copyWith()), fields(r));

      final c = r.copyWith(
        id: 'n', kind: ReminderKind.personal, templateId: 't2', categoryId: 'c2', title: 'T2', body: 'B2', contentType: 'quran',
        scheduleType: ScheduleType.anchor, time: const LocalTime(9, 30), windowStart: const LocalTime(10, 0),
        windowEnd: const LocalTime(20, 0), timesPerDay: 2, daysMask: 96, prayer: Prayer.isha, prayersMask: 31, offsetMin: 15,
        anchor: AnchorKind.wake, startDate: const LocalDate(2026, 2, 1), endDate: const LocalDate(2027, 1, 1), enabled: true,
        pausedUntil: DateTime.utc(2026, 12), respectsQuietHours: true, hideOnLockScreen: false, channel: NiyahChannels.personal,
        syncPolicy: 'cloud', updatedAt: DateTime.utc(2026, 10, 3), deleted: false,
      );
      expect(fields(c), [
        'n', ReminderKind.personal, 't2', 'c2', 'T2', 'B2', 'quran', ScheduleType.anchor, const LocalTime(9, 30),
        const LocalTime(10, 0), const LocalTime(20, 0), 2, 96, Prayer.isha, 31, 15, AnchorKind.wake, const LocalDate(2026, 2, 1),
        const LocalDate(2027, 1, 1), true, DateTime.utc(2026, 12), true, false, NiyahChannels.personal, 'cloud',
        DateTime.utc(2026, 10, 3), false,
      ]);
      // regola fissa: un promemoria struggle non diventa mai cloud
      expect(r.copyWith(kind: ReminderKind.struggle, syncPolicy: 'cloud').syncPolicy, 'local_only');
    });

    test('baseReminderId', () {
      expect(baseReminderId('abc:fajr'), 'abc');
      expect(baseReminderId('abc:wd'), 'abc');
      expect(baseReminderId('prayer'), 'prayer');
    });

    test('DayAnchors: weekend null = come i feriali', () {
      expect(anchors.weekend(AnchorKind.wake), const LocalTime(8, 0));
      expect(anchors.weekend(AnchorKind.sleep), const LocalTime(22, 30));
      expect(anchors.weekday(AnchorKind.sleep), const LocalTime(22, 30));
    });
  });

  group('expandReminders', () {
    test('più preghiere → una per preghiera, id stabili, resto invariato', () {
      final r = prayerRem('x', mask: PrayersMask.all, offset: -15, kind: ReminderKind.template, templateId: 'after_prayer');
      final out = expandReminders([r], anchors);
      expect(out.map((e) => e.id), ['x:fajr', 'x:dhuhr', 'x:asr', 'x:maghrib', 'x:isha']);
      for (final (i, e) in out.indexed) {
        expect(e.prayer, Prayer.values[i]);
        expect(e.prayersMask, isNull);
        expect(e.scheduleType, ScheduleType.prayer);
        expect(e.offsetMin, -15);
        expect(e.kind, ReminderKind.template);
        expect(e.templateId, 'after_prayer');
        expect(e.channel, r.channel);
        expect(e.syncPolicy, r.syncPolicy);
        expect(e.respectsQuietHours, isFalse);
        expect(e.updatedAt, r.updatedAt);
        expect(e.needsExpansion, isFalse);
        expect(e.validate(), isEmpty);
      }
    });

    test('maschera con una sola preghiera → "<id>:fajr"', () {
      final out = expandReminders([prayerRem('m', mask: 1, offset: -20)], anchors);
      expect(out.single.id, 'm:fajr');
      expect(out.single.prayer, Prayer.fajr);
    });

    test('vecchia riga con la sola colonna prayer passa invariata', () {
      final r = prayerRem('old', prayer: Prayer.asr);
      expect(expandReminders([r], anchors).single, same(r));
    });

    test('anchor → settimanale lun–ven all\'orario feriale e sab–dom a quello del weekend', () {
      final out = expandReminders([anchorRem('w', AnchorKind.wake)], anchors);
      expect(out.map((e) => e.id), ['w:wd', 'w:we']);
      expect(out[0].scheduleType, ScheduleType.weekly);
      expect(out[0].time, const LocalTime(6, 40));
      expect(out[0].daysMask, DaysMask.weekdaysOnly);
      expect(out[1].time, const LocalTime(8, 0));
      expect(out[1].daysMask, DaysMask.weekend);
      expect(out.every((e) => e.anchor == null && e.validate().isEmpty), isTrue);
      expect(out.every((e) => e.title == 'Titolo' && e.body == 'Testo'), isTrue);
    });

    test('anchor senza orario del weekend: stesso orario anche sab–dom', () {
      final out = expandReminders([anchorRem('s', AnchorKind.sleep)], anchors);
      expect(out.map((e) => e.time), [const LocalTime(22, 30), const LocalTime(22, 30)]);
    });

    test('anchor: intersezione con i giorni scelti, una parte vuota sparisce', () {
      const monSat = 1 | 32;
      final both = expandReminders([anchorRem('a', AnchorKind.wake, days: monSat)], anchors);
      expect(both.map((e) => (e.id, e.daysMask)), [('a:wd', 1), ('a:we', 32)]);
      final weekdays = expandReminders([anchorRem('b', AnchorKind.wake, days: DaysMask.weekdaysOnly)], anchors);
      expect(weekdays.map((e) => e.id), ['b:wd']);
      final weekend = expandReminders([anchorRem('c', AnchorKind.wake, days: DaysMask.weekend)], anchors);
      expect(weekend.map((e) => e.id), ['c:we']);
    });

    test('anchor senza tipo di anchor: scartato', () {
      expect(expandReminders([anchorRem('a', null)], anchors), isEmpty);
    });

    test('gli altri passano invariati e l\'ordine è conservato; espandere due volte non cambia nulla', () {
      final daily = Reminder(id: 'd', kind: ReminderKind.personal, title: 't', scheduleType: ScheduleType.daily, time: const LocalTime(8, 0), startDate: const LocalDate(2026, 1, 1), updatedAt: DateTime.utc(2026));
      final input = [daily, anchorRem('w', AnchorKind.wake), prayerRem('p', mask: 1 | 16)];
      final once = expandReminders(input, anchors);
      expect(once.map((e) => e.id), ['d', 'w:wd', 'w:we', 'p:fajr', 'p:isha']);
      expect(once.first, same(daily));
      expect(expandReminders(once, anchors).map((e) => e.id), once.map((e) => e.id));
    });

    test('struggle resta privato e locale anche dopo l\'espansione', () {
      final out = expandReminders([anchorRem('s', AnchorKind.sleep, kind: ReminderKind.struggle)], anchors);
      expect(out.every((e) => e.hideOnLockScreen && e.syncPolicy == 'local_only'), isTrue);
    });
  });

  group('pianificatore con promemoria espansi', () {
    test('senza espansione il pianificatore li ignora (nessun errore)', () {
      final plan = planner().plan([anchorRem('w', AnchorKind.wake), prayerRem('p', mask: 31)], at(2026, 10, 13, 10));
      expect(plan.notifications, isEmpty);
    });

    test('anchor: 5 notifiche settimanali alle 06:40 e 2 alle 08:00', () {
      final plan = planner().plan(expandReminders([anchorRem('w', AnchorKind.wake)], anchors), at(2026, 10, 13, 10));
      final n = plan.notifications;
      expect(n, hasLength(7));
      expect(n.every((e) => e.repeat == RepeatKind.weekly), isTrue);
      final wd = n.where((e) => e.reminderId == 'w:wd');
      expect(wd.map((e) => e.fireAt.weekday).toSet(), {1, 2, 3, 4, 5});
      expect(wd.every((e) => e.fireAt.hour == 6 && e.fireAt.minute == 40), isTrue);
      final we = n.where((e) => e.reminderId == 'w:we');
      expect(we.map((e) => e.fireAt.weekday).toSet(), {6, 7});
      expect(we.every((e) => e.fireAt.hour == 8 && e.fireAt.minute == 0), isTrue);
      expect(baseReminderId(n.first.reminderId), 'w');
    });

    test('più preghiere: ogni preghiera ha le sue occorrenze, con i testi del modello', () {
      final r = prayerRem('t', mask: PrayersMask.all, offset: -15, kind: ReminderKind.template, templateId: 'after_prayer');
      final plan = planner(texts: {'after_prayer': const TextPair('Titolo modello', 'Testo modello')})
          .plan(expandReminders([r], anchors), at(2026, 10, 13, 10));
      final real = plan.notifications.where((n) => n.reminderId != '_refresh').toList();
      expect(real.map((n) => n.reminderId).toSet(), {'t:fajr', 't:dhuhr', 't:asr', 't:maghrib', 't:isha'});
      expect(real.every((n) => n.title == 'Titolo modello' && n.body == 'Testo modello'), isTrue);
      final isha = real.firstWhere((n) => n.reminderId == 't:isha');
      final adhan = romePrayers(const LocalDate(2026, 10, 13))!.times[Prayer.isha]!;
      expect(isha.fireAt, adhan.add(const Duration(minutes: 15)));
    });

    test('id stabili: riprogrammare non crea duplicati', () {
      final rs = [anchorRem('w', AnchorKind.wake), prayerRem('p', mask: 31), anchorRem('s', AnchorKind.sleep, days: 1 | 64)];
      final p1 = planner().plan(expandReminders(rs, anchors), at(2026, 10, 13, 10));
      final p2 = planner().plan(expandReminders(rs, anchors), at(2026, 10, 13, 10, 30));
      // Solo la notifica di rinfresco segue "adesso"; tutte le altre restano.
      final diff = p2.diff(p1.notifications.map((n) => n.id));
      expect(diff.toSchedule.map((n) => n.reminderId), ['_refresh']);
      expect(diff.toCancel, [p1.notifications.firstWhere((n) => n.reminderId == '_refresh').id]);
    });

    test('cambiare l\'orario del weekend tocca solo le notifiche del weekend', () {
      final rs = [anchorRem('w', AnchorKind.wake)];
      final now = at(2026, 10, 13, 10);
      final p1 = planner().plan(expandReminders(rs, anchors), now);
      const later = DayAnchors(wake: LocalTime(6, 40), wakeWeekend: LocalTime(9, 0), sleep: LocalTime(22, 30));
      final p2 = planner().plan(expandReminders(rs, later), now);
      final diff = p2.diff(p1.notifications.map((n) => n.id));
      expect(diff.toCancel, hasLength(2));
      expect(diff.toSchedule.map((n) => n.reminderId).toSet(), {'w:we'});
      expect(diff.toSchedule.every((n) => n.fireAt.hour == 9), isTrue);
    });
  });
}
