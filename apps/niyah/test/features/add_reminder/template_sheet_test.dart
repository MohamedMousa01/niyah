import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/features/add_reminder/add_reminder_screen.dart';
import 'package:niyah/features/add_reminder/template_sheet.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';

import '../../core/harness.dart';
import 'add_helpers.dart';

const _five = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};

final _sheetList = find.descendant(of: find.byType(NiyahBottomSheet), matching: find.byType(Scrollable));

void main() {
  setUpAll(loadNiyahFonts);

  group('layout', () {
    // One template per kind; the anchor one shows its weekend stepper.
    const titles = {
      'en': ['Intention before studying', 'After waking up', 'Before each prayer'],
      'it': ['Intenzione prima dello studio', 'Dopo il risveglio', 'Prima di ogni preghiera'],
    };
    for (final lang in ['en', 'it']) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('setup sheets lay out without overflow ($lang, ${dark ? 'dark' : 'light'}, ×$scale)', (
            tester,
          ) async {
            await openAdd(tester, lang: lang, dark: dark, textScale: scale);
            for (final title in titles[lang]!) {
              await openTemplate(tester, title);
              await tester.drag(_sheetList, const Offset(0, -3000));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.byType(PrimaryButton), findsOneWidget);
              await tester.tapAt(const Offset(195, 10)); // the scrim closes the sheet
              await tester.pumpAndSettle();
              expect(find.byType(NiyahBottomSheet), findsNothing);
            }
          });
        }
      }
    }
  });

  group('time kind', () {
    testWidgets('validation and add', (tester) async {
      final notifications = AlarmRecordingNotifications();
      final s = await openAdd(tester, services: addServices(notifications: notifications));
      await openTemplate(tester, 'Intention before studying');
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuoteBox),
          matching: find.text('“Study with the intention of seeking knowledge for the sake of Allah.”'),
        ),
        findsOneWidget,
      );
      expect(find.text('15'), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
      expect(cta(tester).label, 'Add reminder');
      expect(find.text('Remove from my reminders'), findsNothing);

      // Mon–Fri off: nothing left.
      for (var i = 0; i < 5; i++) {
        await tester.tap(dayChip(i));
        await tester.pump();
      }
      expect(cta(tester).label, 'Pick at least one day');
      expect(cta(tester).onPressed, isNull);

      await tester.tap(dayChip(0));
      await tester.pump();
      await tester.tap(tapArea('Hour later'));
      await tester.pump();
      await tester.tap(tapArea('Minutes earlier'));
      await tester.pump();
      expect(find.text('16'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(cta(tester).label, 'Add reminder');

      await tapVisible(tester, find.text('Add reminder'));
      expect(find.byType(NiyahBottomSheet), findsNothing);
      final r = s.reminders.byTemplate('niyyah_study')!;
      expect(r.source, ReminderSource.template);
      expect(r.schedule, const TimeSchedule(LocalTime(16, 55), daysMask: 1));
      expect(notifications.permissionRequests, 1);
      expect(notifications.exactAlarmRequests, 0);
      expect(find.text('16:55 · Monday'), findsOneWidget);
      expect(rowLabelled('Change Intention before studying'), findsOneWidget);
    });

    testWidgets('save changes keeps the reminder and asks nothing', (tester) async {
      final notifications = AlarmRecordingNotifications();
      final s = await openAdd(tester, services: addServices(notifications: notifications));
      await openTemplate(tester, 'Remember Allah in your work');
      expect(cta(tester).label, 'Save changes');
      expect(find.text('Remove from my reminders'), findsOneWidget);
      expect(find.text('09'), findsOneWidget);

      await tester.tap(tapArea('Minutes later'));
      await tester.pump();
      await tester.tap(dayChip(5));
      await tester.pump();
      await tapVisible(tester, find.text('Save changes'));

      expect(find.byType(NiyahBottomSheet), findsNothing);
      final r = s.reminders.byId('t2')!;
      expect(r.schedule, const TimeSchedule(LocalTime(9, 5), daysMask: 0x3F));
      expect(s.reminders.all.where((x) => x.templateId == 'niyyah_work'), hasLength(1));
      expect(notifications.permissionRequests, 0);
    });

    testWidgets('save changes keeps a reminder that is off, off', (tester) async {
      final s = await openAdd(tester);
      await openTemplate(tester, 'Intention with your family');
      await tester.tap(tapArea('Hour earlier'));
      await tester.pump();
      await tapVisible(tester, find.text('Save changes'));
      final r = s.reminders.byId('t4')!;
      expect(r.enabled, isFalse);
      expect(r.schedule, const TimeSchedule(LocalTime(18, 0)));
    });

    testWidgets('remove', (tester) async {
      final s = await openAdd(tester);
      await openTemplate(tester, 'Remember Allah in your work');
      await tapVisible(tester, find.text('Remove from my reminders'));
      expect(find.byType(NiyahBottomSheet), findsNothing);
      expect(s.reminders.byId('t2'), isNull);
      expect(rowLabelled('Set up and add Remember Allah in your work'), findsOneWidget);
    });

    testWidgets('close discards the draft', (tester) async {
      final s = await openAdd(tester);
      await openTemplate(tester, 'Remember Allah in your work');
      await tester.tap(tapArea('Hour later'));
      await tester.pump();
      await tester.tap(tapArea('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(NiyahBottomSheet), findsNothing);
      expect(s.reminders.byId('t2')!.schedule, const TimeSchedule(LocalTime(9, 0), daysMask: 31));
    });
  });

  group('anchor kind', () {
    testWidgets('add edits the shared wake-up times', (tester) async {
      final notifications = AlarmRecordingNotifications();
      final s = await openAdd(tester, services: addServices(notifications: notifications));
      await openTemplate(tester, 'After waking up');
      expect(find.text('Your wake-up time'), findsOneWidget);
      expect(find.text('Every reminder set to “after waking up” follows this time.'), findsOneWidget);
      expect(find.text('06'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Sat & Sun'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(cta(tester).label, 'Add reminder');

      await tester.tap(tapArea('Hour later'));
      await tester.pump();
      await tapVisible(tester, tapArea('Weekend time later'));
      expect(find.text('08:15'), findsOneWidget);
      await tapVisible(tester, find.text('Add reminder'));

      expect(find.byType(NiyahBottomSheet), findsNothing);
      expect(s.settings.anchors.wake, const LocalTime(7, 40));
      expect(s.settings.anchors.wakeWeekend, const LocalTime(8, 15));
      expect(s.settings.anchors.sleep, const LocalTime(22, 30));
      expect(s.reminders.byTemplate('wake_up')!.schedule, const AnchorSchedule(Anchor.wake));
      expect(notifications.permissionRequests, 1);
      expect(find.text('At your wake-up time · 07:40 · weekends 08:15'), findsOneWidget);
    });

    testWidgets('weekend switch: on stores a weekend time, off clears it', (tester) async {
      final s = await openAdd(tester);
      await openTemplate(tester, 'Before sleeping');
      expect(find.text('Your bedtime'), findsOneWidget);
      expect(find.text('Sat & Sun'), findsNothing);

      final weekendSwitch = find.byWidgetPredicate((w) => w is NiyahSwitch && w.semanticLabel == 'Different time on weekends');
      await tapVisible(tester, weekendSwitch);
      expect(find.text('Sat & Sun'), findsOneWidget);
      expect(find.text('23:30'), findsOneWidget);
      await tapVisible(tester, tapArea('Weekend time earlier'));
      expect(find.text('23:15'), findsOneWidget);
      await tapVisible(tester, find.text('Add reminder'));
      expect(s.settings.anchors.sleepWeekend, const LocalTime(23, 15));
      expect(s.settings.anchors.wakeWeekend, const LocalTime(8, 0));

      // Reopen: added now; switch the weekend time off.
      await openTemplate(tester, 'Before sleeping');
      expect(cta(tester).label, 'Save changes');
      expect(find.text('23:15'), findsOneWidget);
      await tapVisible(tester, weekendSwitch);
      expect(find.text('Sat & Sun'), findsNothing);
      await tapVisible(tester, find.text('Save changes'));
      expect(s.settings.anchors.sleepWeekend, isNull);
      expect(s.reminders.all.where((r) => r.templateId == 'before_sleep'), hasLength(1));
      expect(find.text('At your bedtime · 22:30'), findsOneWidget);
    });

    testWidgets('remove keeps the shared times', (tester) async {
      final s = await openAdd(
        tester,
        services: addServices(
          reminders: const [
            ReminderItem(id: 'w', source: ReminderSource.template, templateId: 'wake_up', schedule: AnchorSchedule(Anchor.wake)),
          ],
        ),
      );
      await openTemplate(tester, 'After waking up');
      await tester.tap(tapArea('Hour later'));
      await tester.pump();
      await tapVisible(tester, find.text('Remove from my reminders'));
      expect(s.reminders.byId('w'), isNull);
      expect(s.settings.anchors.wake, const LocalTime(6, 40));
    });
  });

  group('prayer kind', () {
    testWidgets('validation, offset range and add', (tester) async {
      final notifications = AlarmRecordingNotifications();
      final s = await openAdd(tester, services: addServices(notifications: notifications));
      await openTemplate(tester, 'Before each prayer');
      expect(find.text('Which prayers?'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('10 min before adhan'), findsOneWidget);

      // Earlier up to 45 min before.
      for (var i = 0; i < 10; i++) {
        await tester.tap(tapArea('Earlier'));
        await tester.pump();
      }
      expect(find.text('45 min before adhan'), findsOneWidget);
      expect(tester.widget<TapArea>(tapArea('Earlier')).onTap, isNull);

      // Later down to 60 min after.
      for (var i = 0; i < 25; i++) {
        await tester.tap(tapArea('Later'));
        await tester.pump();
      }
      expect(find.text('60 min after adhan'), findsOneWidget);
      expect(tester.widget<TapArea>(tapArea('Later')).onTap, isNull);

      for (var i = 0; i < 12; i++) {
        await tester.tap(tapArea('Earlier'));
        await tester.pump();
      }
      expect(find.text('At adhan'), findsOneWidget);

      // Every prayer off.
      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      expect(cta(tester).label, 'Pick at least one prayer');
      expect(cta(tester).onPressed, isNull);

      await tester.tap(find.text('Fajr'));
      await tester.pump();
      await tester.tap(find.text('Maghrib'));
      await tester.pump();
      await tapVisible(tester, find.text('Add reminder'));

      expect(find.byType(NiyahBottomSheet), findsNothing);
      expect(
        s.reminders.byTemplate('before_prayer')!.schedule,
        const PrayerSchedule({Prayer.fajr, Prayer.maghrib}, offsetMin: 0),
      );
      expect(notifications.permissionRequests, 1);
      expect(notifications.exactAlarmRequests, 1);
      expect(find.text('At adhan · Fajr, Maghrib'), findsOneWidget);
    });

    testWidgets('after-prayer template starts after adhan', (tester) async {
      await openAdd(tester);
      await openTemplate(tester, 'After each prayer');
      expect(find.text('15 min after adhan'), findsOneWidget);
      await tester.tap(tapArea('Later'));
      await tester.pump();
      expect(find.text('20 min after adhan'), findsOneWidget);
    });

    testWidgets('save changes and remove', (tester) async {
      final notifications = AlarmRecordingNotifications();
      final s = await openAdd(
        tester,
        services: addServices(
          notifications: notifications,
          reminders: const [
            ReminderItem(
              id: 'am',
              source: ReminderSource.template,
              templateId: 'adhkar_morning',
              schedule: PrayerSchedule({Prayer.fajr}, offsetMin: -20),
            ),
          ],
        ),
      );
      await openTemplate(tester, 'Morning adhkar');
      expect(cta(tester).label, 'Save changes');
      expect(find.text('20 min after adhan'), findsOneWidget);
      await tester.tap(find.text('Asr'));
      await tester.pump();
      await tester.tap(tapArea('Earlier'));
      await tester.pump();
      await tapVisible(tester, find.text('Save changes'));
      expect(s.reminders.byId('am')!.schedule, const PrayerSchedule({Prayer.fajr, Prayer.asr}, offsetMin: -15));
      expect(notifications.permissionRequests, 0);
      expect(notifications.exactAlarmRequests, 0);

      await openTemplate(tester, 'Morning adhkar');
      await tapVisible(tester, find.text('Remove from my reminders'));
      expect(s.reminders.byId('am'), isNull);
      expect(find.text('20 min after adhan · Fajr'), findsOneWidget);
    });

    testWidgets('Italian sheet', (tester) async {
      await openAdd(tester, lang: 'it');
      await openTemplate(tester, 'Prima di ogni preghiera');
      expect(find.text('Quali preghiere?'), findsOneWidget);
      expect(find.text('10 min prima dell\'adhan'), findsOneWidget);
      expect(cta(tester).label, 'Aggiungi promemoria');
      for (final p in _five) {
        await tester.tap(find.text(switch (p) {
          Prayer.fajr => 'Fajr',
          Prayer.dhuhr => 'Dhuhr',
          Prayer.asr => 'Asr',
          Prayer.maghrib => 'Maghrib',
          Prayer.isha => 'Isha',
        }));
        await tester.pump();
      }
      expect(cta(tester).label, 'Scegli almeno una preghiera');
    });
  });

  testWidgets('template row in My reminders opens the same sheet', (tester) async {
    final s = await pumpApp(tester, services: addServices());
    await tester.tap(find.text('Reminders').last);
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);

    await tester.tap(find.text('Remember Allah in your work'));
    await tester.pumpAndSettle();
    expect(find.byType(NiyahBottomSheet), findsOneWidget);
    expect(cta(tester).label, 'Save changes');

    await tester.tap(tapArea('Hour later'));
    await tester.pump();
    await tapVisible(tester, find.text('Save changes'));
    expect(find.byType(NiyahBottomSheet), findsNothing);
    expect(s.reminders.byId('t2')!.schedule, const TimeSchedule(LocalTime(10, 0), daysMask: 31));
    expect(find.text('10:00 · Mon–Fri'), findsOneWidget);
  });

  testWidgets('unknown template id opens nothing', (tester) async {
    await openAdd(tester);
    await showTemplateSheet(tester.element(find.byType(AddReminderScreen)), 'missing');
    await tester.pumpAndSettle();
    expect(find.byType(NiyahBottomSheet), findsNothing);
  });
}
