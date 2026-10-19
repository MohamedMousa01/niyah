import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/features/editor/editor_screen.dart';
import 'package:niyah/features/editor/editor_widgets.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';
import 'package:niyah/router.dart';

import '../../core/harness.dart';

/// Opens My reminders, then pushes [route] on top of it.
Future<AppServices> openOnReminders(
  WidgetTester tester,
  String route, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  final s = await pumpApp(tester, services: services, lang: lang, dark: dark, textScale: textScale);
  await tester.tap(find.text(lang == 'en' ? 'Reminders' : 'Promemoria').last);
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(RemindersScreen))).push(route);
  await tester.pumpAndSettle();
  return s;
}

final editorList = find.descendant(of: find.byType(EditorScreen), matching: find.byType(Scrollable)).first;
final titleField = find.byType(TextField).at(0);
final bodyField = find.byType(TextField).at(1);
final timeRow = find.descendant(of: find.byType(TimeCard), matching: find.byType(InkWell)).first;

Finder inPreview(String text) => find.descendant(of: find.byType(NotificationPreview), matching: find.text(text));

PrimaryButton saveButton(WidgetTester tester) => tester.widget<PrimaryButton>(find.byType(PrimaryButton));

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadNiyahFonts);

  group('layout', () {
    for (final lang in ['en', 'it']) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          final name = '$lang, ${dark ? 'dark' : 'light'}, ×$scale';

          testWidgets('new reminder lays out without overflow ($name)', (tester) async {
            await openOnReminders(tester, Routes.newReminder, lang: lang, dark: dark, textScale: scale);
            await tester.enterText(titleField, 'A rather long title to fill the preview line');
            await tester.pumpAndSettle();
            // Open the time stepper, then switch to the prayer card.
            await tapVisible(tester, timeRow);
            expect(find.byType(TimeStepper), findsOneWidget);
            await tester.drag(editorList, const Offset(0, -3000));
            await tester.pumpAndSettle();
            await tapVisible(tester, find.text(lang == 'en' ? 'Around a prayer' : 'Intorno a una preghiera'));
            await tester.drag(editorList, const Offset(0, -3000));
            await tester.pumpAndSettle();
            expect(find.byType(PrayerCard), findsOneWidget);
            expect(tester.takeException(), isNull);
          });

          testWidgets('edit reminder and delete sheet lay out without overflow ($name)', (tester) async {
            await openOnReminders(tester, Routes.edit('p1'), lang: lang, dark: dark, textScale: scale);
            await tester.drag(editorList, const Offset(0, -3000));
            await tester.pumpAndSettle();
            await tester.tap(find.byWidgetPredicate((w) => w is NiyahTextButton && w.danger));
            await tester.pumpAndSettle();
            expect(find.byType(NiyahBottomSheet), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('new: shows the design content and fallbacks', (tester) async {
    await openOnReminders(tester, Routes.newReminder);
    expect(find.text('Write your own'), findsOneWidget);
    expect(find.text('HOW IT WILL ARRIVE'), findsOneWidget);
    expect(inPreview('Your title'), findsOneWidget);
    expect(inPreview('Your message will appear here.'), findsOneWidget);
    expect(inPreview('08:00'), findsOneWidget);
    expect(find.text('140 left'), findsOneWidget);
    expect(find.text('When should it reach you?'), findsOneWidget);
    expect(find.text('Your words stay on this phone. Quiet hours are respected.'), findsOneWidget);
    expect(find.text('Delete reminder'), findsNothing);
  });

  testWidgets('create: saves a personal reminder, asks permission, pops back', (tester) async {
    final notifications = RecordingNotifications();
    final s = await openOnReminders(tester, Routes.newReminder, services: fakeServices(notifications: notifications));
    final before = s.reminders.all.length;

    await tester.enterText(titleField, 'Pray with presence');
    await tester.enterText(bodyField, 'Slow down.');
    await tester.pumpAndSettle();
    expect(inPreview('Pray with presence'), findsOneWidget);
    expect(inPreview('Slow down.'), findsOneWidget);
    expect(find.text('130 left'), findsOneWidget);

    // Time 09:05 on weekdays.
    await tapVisible(tester, timeRow);
    await tapVisible(tester, find.bySemanticsLabel('Hour later'));
    await tapVisible(tester, find.bySemanticsLabel('Minutes later'));
    expect(inPreview('09:05'), findsOneWidget);
    await tapVisible(tester, find.bySemanticsLabel('Saturday'));
    await tapVisible(tester, find.bySemanticsLabel('Sunday'));

    await tapVisible(tester, find.text('Save reminder'));
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(notifications.permissionRequests, 1);
    expect(s.reminders.all.length, before + 1);
    final created = s.reminders.all.firstWhere((r) => r.title == 'Pray with presence');
    expect(created.source, ReminderSource.personal);
    expect(created.body, 'Slow down.');
    expect(created.enabled, isTrue);
    expect(created.schedule, const TimeSchedule(LocalTime(9, 5), daysMask: DaysMask.weekdaysOnly));
    expect(find.text('Pray with presence'), findsOneWidget);
  });

  testWidgets('create around a prayer: chips and offset limits', (tester) async {
    final s = await openOnReminders(tester, Routes.newReminder);
    await tester.enterText(bodyField, 'Only a message');
    await tapVisible(tester, find.text('Around a prayer'));
    expect(inPreview('before Fajr'), findsOneWidget);
    expect(find.text('10 min before adhan'), findsOneWidget);

    await tapVisible(tester, find.bySemanticsLabel('Asr'));
    await tapVisible(tester, find.bySemanticsLabel('Fajr'));
    expect(inPreview('before Asr'), findsOneWidget);

    final later = find.bySemanticsLabel('Later');
    final earlier = find.bySemanticsLabel('Earlier');
    for (var i = 0; i < 2; i++) {
      await tapVisible(tester, later);
    }
    expect(find.text('At adhan'), findsOneWidget);
    expect(inPreview('at Asr'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tapVisible(tester, later);
    }
    expect(find.text('45 min after adhan'), findsOneWidget);
    expect(inPreview('after Asr'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tapVisible(tester, earlier);
    }
    expect(find.text('60 min before adhan'), findsOneWidget);

    await tapVisible(tester, find.text('Save reminder'));
    final created = s.reminders.all.firstWhere((r) => r.body == 'Only a message');
    expect(created.title, isNull);
    expect(created.schedule, const PrayerSchedule({Prayer.asr}, offsetMin: 60));
  });

  testWidgets('validation: text, days and prayers', (tester) async {
    await openOnReminders(tester, Routes.newReminder);
    expect(saveButton(tester).label, 'Write a title or a message.');
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(titleField, '   ');
    await tester.pumpAndSettle();
    expect(saveButton(tester).label, 'Write a title or a message.');

    await tester.enterText(titleField, 'Hello');
    await tester.pumpAndSettle();
    expect(saveButton(tester).label, 'Save reminder');
    expect(saveButton(tester).onPressed, isNotNull);

    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
      await tapVisible(tester, find.bySemanticsLabel(day));
    }
    expect(saveButton(tester).label, 'Pick at least one day');
    expect(saveButton(tester).onPressed, isNull);

    await tapVisible(tester, find.text('Around a prayer'));
    expect(saveButton(tester).label, 'Save reminder');
    await tapVisible(tester, find.bySemanticsLabel('Fajr'));
    expect(saveButton(tester).label, 'Pick at least one prayer');
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('validation messages in Italian', (tester) async {
    await openOnReminders(tester, Routes.newReminder, lang: 'it');
    expect(find.text('Scrivi un titolo o un messaggio.'), findsOneWidget);
    await tester.enterText(titleField, 'Ciao');
    await tester.pumpAndSettle();
    expect(find.text('Salva promemoria'), findsOneWidget);
    expect(find.text('140 rimasti'), findsOneWidget);
  });

  testWidgets('ideas fill the title and the message', (tester) async {
    await openOnReminders(tester, Routes.newReminder);
    await tapVisible(tester, find.byWidgetPredicate((w) => w is IdeaChip && w.label == 'Renew your intention'));
    expect(tester.widget<TextField>(titleField).controller!.text, 'Renew your intention');
    expect(tester.widget<TextField>(bodyField).controller!.text, 'Let this be for the pleasure of Allah.');
    expect(inPreview('Let this be for the pleasure of Allah.'), findsOneWidget);
    await tapVisible(tester, find.byWidgetPredicate((w) => w is IdeaChip && w.label == 'Begin with Bismillah'));
    expect(tester.widget<TextField>(titleField).controller!.text, 'Begin with Bismillah');
    expect(saveButton(tester).label, 'Save reminder');
  });

  testWidgets('title and message are limited to 60 and 140 characters', (tester) async {
    await openOnReminders(tester, Routes.newReminder);
    await tester.enterText(titleField, 'x' * 80);
    await tester.enterText(bodyField, 'y' * 200);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(titleField).controller!.text.length, 60);
    expect(tester.widget<TextField>(bodyField).controller!.text.length, 140);
    expect(find.text('0 left'), findsOneWidget);
  });

  testWidgets('edit: loads the reminder and saves changes', (tester) async {
    final s = await openOnReminders(tester, Routes.edit('p1'));
    expect(find.text('Edit reminder'), findsOneWidget);
    expect(tester.widget<TextField>(titleField).controller!.text, 'Why am I doing this?');
    expect(inPreview('07:15'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Delete reminder'), findsOneWidget);

    await tester.enterText(titleField, 'Is it for Him?');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save changes'));
    expect(find.byType(RemindersScreen), findsOneWidget);
    final r = s.reminders.byId('p1')!;
    expect(r.title, 'Is it for Him?');
    expect(r.body, 'Pause — make it for Allah, not for the eyes of people.');
    expect(r.schedule, const TimeSchedule(LocalTime(7, 15)));
  });

  testWidgets('edit: a wake-up reminder keeps its anchor unless the schedule changes', (tester) async {
    final s = await openOnReminders(tester, Routes.edit('p2'));
    expect(inPreview('06:40'), findsOneWidget);
    await tapVisible(tester, find.text('Save changes'));
    expect(s.reminders.byId('p2')!.schedule, const AnchorSchedule(Anchor.wake));

    GoRouter.of(tester.element(find.byType(RemindersScreen))).push(Routes.edit('p2'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel('Sunday'));
    await tapVisible(tester, find.text('Save changes'));
    expect(s.reminders.byId('p2')!.schedule, const TimeSchedule(LocalTime(6, 40), daysMask: 63));
  });

  testWidgets('delete: removes the reminder and pops back to My reminders', (tester) async {
    final s = await openOnReminders(tester, Routes.edit('p1'));
    await tapVisible(tester, find.text('Delete reminder'));
    expect(find.text('Delete this reminder?'), findsOneWidget);
    expect(find.textContaining('“Why am I doing this?” will be removed'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(s.reminders.byId('p1'), isNull);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('Why am I doing this?'), findsNothing);
  });

  testWidgets('turn it off instead: disables and pops', (tester) async {
    final s = await openOnReminders(tester, Routes.edit('p1'));
    await tapVisible(tester, find.text('Delete reminder'));
    await tester.tap(find.text('Turn it off instead'));
    await tester.pumpAndSettle();
    expect(s.reminders.byId('p1')!.enabled, isFalse);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(RemindersScreen), findsOneWidget);
  });

  testWidgets('cancel closes the sheet and keeps the reminder', (tester) async {
    final s = await openOnReminders(tester, Routes.edit('p1'));
    await tapVisible(tester, find.text('Delete reminder'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this reminder?'), findsNothing);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(s.reminders.byId('p1')!.enabled, isTrue);
  });

  testWidgets('delete sheet in Italian', (tester) async {
    await openOnReminders(tester, Routes.edit('p1'), lang: 'it', dark: true);
    await tapVisible(tester, find.text('Elimina promemoria'));
    expect(find.text('Eliminare questo promemoria?'), findsOneWidget);
    expect(find.text('Disattivalo invece'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
  });
}
