import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/features/add_reminder/add_reminder_screen.dart';
import 'package:niyah/features/editor/editor_screen.dart';
import 'package:niyah/features/prayer/prayer_screen.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';

import '../../core/harness.dart';

Future<AppServices> openReminders(
  WidgetTester tester, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  final s = await pumpApp(tester, services: services, lang: lang, dark: dark, textScale: textScale);
  await tester.tap(find.text(lang == 'en' ? 'Reminders' : 'Promemoria').last);
  await tester.pumpAndSettle();
  expect(find.byType(RemindersScreen), findsOneWidget);
  return s;
}

final remindersList = find.descendant(of: find.byType(RemindersScreen), matching: find.byType(Scrollable));

Finder switchOf(String title) => find.byWidgetPredicate((w) => w is NiyahSwitch && w.semanticLabel == title);

void main() {
  setUpAll(loadNiyahFonts);

  for (final lang in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('My reminders lays out without overflow ($lang, ${dark ? 'dark' : 'light'}, ×$scale)', (
          tester,
        ) async {
          await openReminders(tester, lang: lang, dark: dark, textScale: scale);
          // Expand "From Niyah" and scroll to the very end.
          final more = find.text(lang == 'en' ? 'Show 1 more' : 'Mostra altri 1');
          await tester.scrollUntilVisible(more, 300, scrollable: remindersList);
          await tester.ensureVisible(more);
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
          await tester.drag(remindersList, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('sections show the design content', (tester) async {
    await openReminders(tester);
    expect(find.text('WRITTEN BY ME'), findsOneWidget);
    expect(find.text('Why am I doing this?'), findsOneWidget);
    expect(find.text('07:15 · Every day'), findsOneWidget);
    expect(find.text('At your wake-up time · 06:40 · weekends 08:00'), findsOneWidget);
    expect(find.text('PRAYER'), findsOneWidget);
    expect(find.text('Before each prayer'), findsOneWidget);
    expect(find.text('Fajr, Dhuhr, Asr, Maghrib, Isha · 10 min before'), findsOneWidget);
    expect(find.text('FROM NIYAH'), findsOneWidget);
    expect(find.text('09:00 · Mon–Fri'), findsOneWidget);
    expect(find.text('Notifications are off'), findsNothing);
  });

  testWidgets('template texts come from the template repository (it)', (tester) async {
    await openReminders(tester, lang: 'it');
    expect(find.text('Rinnova la tua intenzione'), findsOneWidget);
    expect(find.text('Ricorda Allah nel tuo lavoro'), findsOneWidget);
    expect(find.text('Prima di ogni preghiera'), findsOneWidget);
  });

  testWidgets('show more / show less', (tester) async {
    await openReminders(tester);
    expect(find.text('Intention with your family'), findsNothing);
    await tester.ensureVisible(find.text('Show 1 more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 1 more'));
    await tester.pumpAndSettle();
    expect(find.text('Intention with your family'), findsOneWidget);
    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('Intention with your family'), findsNothing);
  });

  testWidgets('switching off and on updates the repository; on asks permission first', (tester) async {
    final notifications = RecordingNotifications();
    final s = await openReminders(tester, services: fakeServices(notifications: notifications));

    await tester.tap(switchOf('Why am I doing this?'));
    await tester.pumpAndSettle();
    expect(s.reminders.byId('p1')!.enabled, isFalse);
    expect(find.text('Off'), findsNWidgets(2)); // + the dhikr reminder, off in the sample
    expect(notifications.permissionRequests, 0);

    await tester.tap(switchOf('Why am I doing this?'));
    await tester.pumpAndSettle();
    expect(s.reminders.byId('p1')!.enabled, isTrue);
    expect(notifications.permissionRequests, 1);
  });

  testWidgets('notifications off: discreet row opens the system settings', (tester) async {
    final notifications = RecordingNotifications()..permission = false;
    await openReminders(tester, services: fakeServices(notifications: notifications));
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    await tester.tap(find.textContaining('Open settings'));
    await tester.pumpAndSettle();
    expect(notifications.settingsOpened, 1);
  });

  testWidgets('Add pill opens Add a reminder', (tester) async {
    await openReminders(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AddReminderScreen), findsOneWidget);
  });

  testWidgets('personal row opens the editor, prayer card the Prayer screen', (tester) async {
    await openReminders(tester);
    await tester.tap(find.text('Before I open my phone'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.widget<EditorScreen>(find.byType(EditorScreen)).reminderId, 'p2');

    await tester.tap(find.byWidgetPredicate((w) => w is TapArea && w.semanticLabel == 'Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before each prayer'));
    await tester.pumpAndSettle();
    expect(find.byType(PrayerScreen), findsOneWidget);
  });

  testWidgets('template row opens the setup sheet', (tester) async {
    await openReminders(tester);
    await tester.tap(find.text('Remember Allah in your work'));
    await tester.pumpAndSettle();
    // The sheet itself belongs to the add-reminder package (placeholder: a snack bar).
    expect(find.byType(SnackBar).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('empty "Written by me" offers to write one', (tester) async {
    final reminders = FakeReminderRepository(
      initial: [
        for (final r in FakeReminderRepository.sampleReminders)
          if (r.source != ReminderSource.personal) r,
      ],
    );
    await openReminders(tester, services: fakeServices(reminders: reminders));
    expect(find.text("You haven't written a reminder yet."), findsOneWidget);
    await tester.tap(find.text('Write your own'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.widget<EditorScreen>(find.byType(EditorScreen)).reminderId, isNull);
  });

  testWidgets('prayer card title follows the timing mode', (tester) async {
    final s = await openReminders(tester);
    final p = s.reminders.prayer;
    await s.reminders.save(p.copyWith(schedule: (p.schedule as PrayerSchedule).copyWith(offsetMin: -15)));
    await tester.pumpAndSettle();
    expect(find.text('After each prayer'), findsOneWidget);
    expect(find.text('Fajr, Dhuhr, Asr, Maghrib, Isha · After prayer'), findsOneWidget);
    await s.reminders.save(p.copyWith(schedule: (p.schedule as PrayerSchedule).copyWith(offsetMin: 0)));
    await tester.pumpAndSettle();
    expect(find.text('At each adhan'), findsOneWidget);
  });
}
