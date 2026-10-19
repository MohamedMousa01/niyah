import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/features/editor/editor_screen.dart';
import 'package:niyah/features/prayer/prayer_screen.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';
import 'package:niyah/router.dart';

import '../../core/harness.dart';

class _Notifications extends RecordingNotifications {
  int exactAlarmRequests = 0;

  @override
  Future<bool> ensureExactAlarms() async {
    exactAlarmRequests++;
    return true;
  }
}

Future<AppServices> openPrayer(
  WidgetTester tester, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  final s = await pumpApp(tester, services: services, lang: lang, dark: dark, textScale: textScale);
  await tester.tap(find.text(lang == 'en' ? 'Reminders' : 'Promemoria').last);
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(RemindersScreen))).push(Routes.prayer);
  await tester.pumpAndSettle();
  expect(find.byType(PrayerScreen), findsOneWidget);
  return s;
}

final prayerList = find.descendant(of: find.byType(PrayerScreen), matching: find.byType(Scrollable)).first;

Finder switchOf(String label) => find.byWidgetPredicate((w) => w is NiyahSwitch && w.semanticLabel == label);

PrayerSchedule scheduleOf(AppServices s) => s.reminders.prayer.schedule as PrayerSchedule;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadNiyahFonts);

  for (final lang in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Prayer lays out without overflow ($lang, ${dark ? 'dark' : 'light'}, ×$scale)', (tester) async {
          await openPrayer(tester, lang: lang, dark: dark, textScale: scale);
          await tester.drag(prayerList, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('shows the design content', (tester) async {
    await openPrayer(tester);
    expect(find.text('Prayer reminders'), findsOneWidget);
    expect(find.text('THE MESSAGE'), findsOneWidget);
    expect(find.text('Renew your intention'), findsOneWidget);
    expect(find.textContaining('is near. Prepare your heart, and pray it for Allah alone.'), findsOneWidget);
    expect(find.text('Change the words'), findsOneWidget);
    expect(find.text('How long before'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Milan · Muslim World League'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('الفجر'), findsOneWidget);
    expect(find.text('05:58'), findsOneWidget);
    expect(find.text('19:45'), findsOneWidget);
    expect(find.text('10 min before'), findsNWidgets(5));
    expect(find.text('Also during quiet hours'), findsOneWidget);
  });

  testWidgets('Italian texts', (tester) async {
    await openPrayer(tester, lang: 'it');
    expect(find.text('Promemoria di preghiera'), findsOneWidget);
    expect(find.text('Cambia le parole'), findsOneWidget);
    expect(find.text('Quanto prima'), findsOneWidget);
    expect(find.text('10 min prima'), findsNWidgets(5));
    expect(find.text('Anche durante il non disturbare'), findsOneWidget);
  });

  testWidgets('timing modes save at once and restore the minutes', (tester) async {
    final s = await openPrayer(tester);

    await tester.tap(find.text('At adhan'));
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, 0);
    expect(find.text('How long before'), findsNothing);
    expect(find.textContaining("It's time for"), findsOneWidget);
    expect(find.text('At adhan'), findsNWidgets(6)); // segment + 5 rows

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, PrayerScreen.afterOffset);
    expect(find.text('Take a moment after the prayer, and keep your heart with Allah.'), findsOneWidget);
    expect(find.text('After prayer'), findsNWidgets(5));

    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, 10);
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('minutes stepper stays between 5 and 45', (tester) async {
    final s = await openPrayer(tester);
    final less = find.bySemanticsLabel('Less time');
    final more = find.bySemanticsLabel('More time');

    await tester.tap(less);
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, 5);
    expect(
      tester.widget<TapArea>(find.byWidgetPredicate((w) => w is TapArea && w.semanticLabel == 'Less time')).onTap,
      isNull,
    );
    await tester.tap(less);
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, 5);

    for (var i = 0; i < 12; i++) {
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
    expect(scheduleOf(s).offsetMin, 45);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('45 min before'), findsNWidgets(5));

    // Leaving "Before" and coming back keeps the chosen minutes.
    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();
    expect(scheduleOf(s).offsetMin, 45);
  });

  testWidgets('prayer switches edit the set; first switch on asks permissions', (tester) async {
    final notifications = _Notifications();
    final s = await openPrayer(tester, services: fakeServices(notifications: notifications));

    await tapVisible(tester, switchOf('Remind me for Isha'));
    expect(scheduleOf(s).prayers, {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib});
    expect(find.text('Off'), findsOneWidget);
    expect(notifications.permissionRequests, 0);

    await tapVisible(tester, switchOf('Remind me for Isha'));
    expect(scheduleOf(s).prayers, contains(Prayer.isha));
    expect(notifications.permissionRequests, 1);
    expect(notifications.exactAlarmRequests, 1);

    await tapVisible(tester, switchOf('Remind me for Fajr'));
    await tapVisible(tester, switchOf('Remind me for Fajr'));
    expect(scheduleOf(s).prayers.length, 5);
    expect(notifications.permissionRequests, 1);
    expect(s.reminders.prayer.enabled, isTrue);
  });

  testWidgets('a disabled prayer reminder shows every prayer off; a switch turns it back on', (tester) async {
    final s = await openPrayer(tester);
    await s.reminders.setEnabled(s.reminders.prayer.id, false);
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsNWidgets(5));

    await tapVisible(tester, switchOf('Remind me for Asr'));
    expect(s.reminders.prayer.enabled, isTrue);
    expect(scheduleOf(s).prayers, {Prayer.asr});
  });

  testWidgets('quiet hours switch updates the setting', (tester) async {
    final s = await openPrayer(tester);
    expect(s.settings.prayerDuringQuiet, isTrue);
    final quiet = switchOf('Prayer reminders during quiet hours');
    await tapVisible(tester, quiet);
    expect(s.settings.prayerDuringQuiet, isFalse);
    expect(tester.widget<NiyahSwitch>(quiet).value, isFalse);
    await tapVisible(tester, quiet);
    expect(s.settings.prayerDuringQuiet, isTrue);
  });

  testWidgets('prayer words: round trip and reset to the default words', (tester) async {
    final s = await openPrayer(tester);
    await tapVisible(tester, find.text('Change the words'));
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('When should it reach you?'), findsNothing);
    expect(find.text('Delete reminder'), findsNothing);
    // Empty fields: the preview shows the default words.
    final preview = find.byType(NotificationPreview);
    expect(find.descendant(of: preview, matching: find.text('Renew your intention')), findsOneWidget);
    expect(find.descendant(of: preview, matching: find.textContaining('before ')), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Stand before your Lord');
    await tester.enterText(find.byType(TextField).at(1), 'Leave the world for a moment.');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save changes'));

    expect(find.byType(PrayerScreen), findsOneWidget);
    expect(s.reminders.prayer.title, 'Stand before your Lord');
    expect(s.reminders.prayer.body, 'Leave the world for a moment.');
    expect(find.text('Stand before your Lord'), findsOneWidget);
    expect(find.text('Leave the world for a moment.'), findsOneWidget);
    expect(scheduleOf(s).prayers.length, 5); // schedule untouched

    await tapVisible(tester, find.text('Change the words'));
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, 'Stand before your Lord');
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save changes'));

    expect(s.reminders.prayer.title, isNull);
    expect(s.reminders.prayer.body, isNull);
    expect(find.text('Renew your intention'), findsOneWidget);
    expect(find.textContaining('is near.'), findsOneWidget);
  });
}
