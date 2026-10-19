import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/l10n/app_localizations.dart';
import 'package:niyah/notifications/schedule_builder.dart';
import 'package:niyah/notifications/schedule_inputs.dart';
import 'package:niyah_core/niyah_core.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'fakes.dart';

void main() {
  late tz.Location rome;
  late tz.TZDateTime now;
  final en = lookupAppLocalizations(const Locale('en'));
  final it = lookupAppLocalizations(const Locale('it'));

  setUpAll(() {
    tzdata.initializeTimeZones();
    rome = tz.getLocation('Europe/Rome');
    now = tz.TZDateTime(rome, 2026, 10, 19, 8);
  });

  Future<SchedulePlan> plan(InMemoryScheduleInputs inputs, {int budget = 200, AppLocalizations? l10n}) =>
      buildSchedulePlan(inputs: inputs, l10n: l10n ?? en, location: rome, now: now, budget: budget);

  group('texts', () {
    test('device locale falls back to English', () {
      expect(notificationLocalizations(const Locale('it', 'IT')).localeName, 'it');
      expect(notificationLocalizations(const Locale('fr')).localeName, 'en');
    });

    test('prayer body follows the offset sign', () {
      expect(prayerBody(en, Prayer.asr, 15), 'Asr in 15 minutes');
      expect(prayerBody(en, Prayer.asr, 0), "It's time for Asr");
      expect(prayerBody(en, Prayer.asr, -20), en.prayerDefaultBodyAfter);
      expect(prayerBody(it, Prayer.asr, -20), it.prayerDefaultBodyAfter);
    });

    test('planner strings keep their placeholders', () {
      final s = notificationStrings(en);
      expect(s.prayerAtTime, "It's time for {prayer}");
      expect(s.prayerBefore, '{prayer} in {minutes} minutes');
      expect(s.prayerNames[Prayer.maghrib], 'Maghrib');
      expect(s.refreshTitle, 'MyNiyah');
    });

    test('every channel has a localized name', () {
      final names = channelNames(it);
      expect(names.keys, unorderedEquals(NiyahChannels.all));
      expect(names[NiyahChannels.personal], it.channelPersonal);
    });
  });

  group('prepareReminders', () {
    test('fills the default body of the prayer reminder only', () {
      final mine = personal('p');
      final out = prepareReminders(
        [prayer(Prayer.fajr), prayer(Prayer.isha, offset: -10), prayer(Prayer.asr, body: 'Mine'), mine],
        en,
        prayerDuringQuiet: true,
      );
      expect(out[0].body, 'Fajr in 10 minutes');
      expect(out[0].title, isNull, reason: 'the planner uses the prayer name');
      expect(out[0].id, 'prayer:fajr');
      expect(out[1].body, en.prayerDefaultBodyAfter);
      expect(out[2].body, 'Mine');
      expect(out[3], same(mine));
    });

    test('prayer reminders follow the quiet-hours switch', () {
      final ring = prepareReminders([prayer(Prayer.fajr), personal('p')], en, prayerDuringQuiet: true);
      final silent = prepareReminders([prayer(Prayer.fajr)], en, prayerDuringQuiet: false);
      expect(ring[0].respectsQuietHours, isFalse);
      expect(ring[1].respectsQuietHours, isTrue);
      expect(silent[0].respectsQuietHours, isTrue);
    });
  });

  group('buildSchedulePlan', () {
    test('fixed reminders become repeating OS entries', () async {
      final p = await plan(InMemoryScheduleInputs(reminders: [
        personal('daily'),
        personal('weekly', days: 0x01 | 0x04 | 0x10), // Mon, Wed, Fri
      ]));
      expect(p.notifications.where((n) => n.reminderId == 'daily').single.repeat, RepeatKind.daily);
      final weekly = p.notifications.where((n) => n.reminderId == 'weekly').toList();
      expect(weekly, hasLength(3));
      expect(weekly.every((n) => n.repeat == RepeatKind.weekly), isTrue);
      expect(p.notifications.any((n) => n.reminderId == '_refresh'), isFalse);
    });

    test('templates use the texts of the active language', () async {
      final inputs = InMemoryScheduleInputs(
        reminders: [template('t1', 'renew')],
        templates: {
          'en': {'renew': const TextPair('Renew', 'Renew your intention')},
          'it': {'renew': const TextPair('Rinnova', 'Rinnova la tua intenzione')},
        },
      );
      expect((await plan(inputs)).notifications.single.title, 'Renew');
      expect((await plan(inputs, l10n: it)).notifications.single.title, 'Rinnova');
    });

    test('prayer reminders are one-offs with default texts and a refresh', () async {
      final p = await plan(InMemoryScheduleInputs(reminders: allPrayers()));
      final prayers = p.notifications.where((n) => n.reminderId.startsWith('prayer:')).toList();
      // 14-day window: about 5 a day, all single occurrences.
      expect(prayers.length, inInclusiveRange(70, 75));
      expect(prayers.every((n) => n.repeat == RepeatKind.none && n.channel == NiyahChannels.prayer), isTrue);
      final asr = prayers.firstWhere((n) => n.reminderId == 'prayer:asr');
      expect(asr.title, 'Asr');
      expect(asr.body, 'Asr in 10 minutes');
      expect(asr.fireAt.isAfter(now), isTrue);
      final refresh = p.notifications.where((n) => n.reminderId == '_refresh').single;
      expect(refresh.title, 'MyNiyah');
      expect(refresh.body, en.notifRefreshBody);
    });

    test('the iOS budget caps the plan and keeps a slot for the refresh', () async {
      final p = await plan(
        InMemoryScheduleInputs(reminders: [personal('daily'), ...allPrayers()]),
        budget: 60,
      );
      expect(p.notifications, hasLength(60));
      expect(p.notifications.where((n) => n.reminderId == 'daily'), hasLength(1));
      expect(p.notifications.where((n) => n.reminderId == '_refresh'), hasLength(1));
      expect(p.windowEnd!.isBefore(now.add(const Duration(days: 14))), isTrue);
    });

    test('repeating reminders that do not fit are reported', () async {
      final p = await plan(
        InMemoryScheduleInputs(reminders: [personal('a'), personal('b', days: 0x7E)]),
        budget: 3,
      );
      expect(p.notifications.map((n) => n.reminderId), ['a']);
      expect(p.overBudgetReminderIds, ['b']);
    });

    test('quiet hours silence Fajr unless prayers may ring', () async {
      // Fajr in Milan in October is around 06:20, inside 22:30–07:00.
      const quiet = QuietHours(enabled: true);
      final silent = await plan(InMemoryScheduleInputs(
        reminders: [prayer(Prayer.fajr, offset: 0)],
        quietHours: quiet,
        prayerDuringQuiet: false,
      ));
      final ring = await plan(InMemoryScheduleInputs(
        reminders: [prayer(Prayer.fajr, offset: 0)],
        quietHours: quiet,
        prayerDuringQuiet: true,
      ));
      expect(silent.notifications.where((n) => n.reminderId == 'prayer:fajr'), isEmpty);
      expect(ring.notifications.where((n) => n.reminderId == 'prayer:fajr'), isNotEmpty);
    });

    test('a global pause holds everything back until it ends', () async {
      final until = now.add(const Duration(days: 3)).toUtc();
      final p = await plan(InMemoryScheduleInputs(reminders: allPrayers(), pausedUntil: until));
      final prayers = p.notifications.where((n) => n.reminderId.startsWith('prayer:'));
      expect(prayers, isNotEmpty);
      expect(prayers.every((n) => !n.fireAt.toUtc().isBefore(until)), isTrue);
    });
  });
}
