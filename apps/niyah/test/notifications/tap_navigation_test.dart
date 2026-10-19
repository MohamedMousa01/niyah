import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/features/editor/editor_screen.dart';
import 'package:niyah/features/home/home_screen.dart';
import 'package:niyah/features/prayer/prayer_screen.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';
import 'package:niyah/features/settings/location_screen.dart';
import 'package:niyah/router.dart';

import '../core/harness.dart';

/// Simulates the OS handing over a tapped notification.
Future<void> tap(WidgetTester tester, AppServices s, String payload) async {
  (s.notifications as FakeNotificationService).tappedPayload.value = payload;
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadNiyahFonts);

  testWidgets('a personal reminder opens its editor, and Back leads to My reminders', (tester) async {
    final s = await pumpApp(tester);
    await tap(tester, s, '{"r":"p1"}');
    final editor = tester.widget<EditorScreen>(find.byType(EditorScreen));
    expect(editor.reminderId, 'p1');
    expect(find.text('Edit reminder'), findsOneWidget);
    expect(s.notifications.tappedPayload.value, isNull); // handled once

    await tester.tap(find.descendant(of: find.byType(BackHeader), matching: find.byType(TapArea)).first);
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);
  });

  testWidgets('an anchor reminder (expanded id) opens the same editor', (tester) async {
    final s = await pumpApp(tester);
    await tap(tester, s, '{"r":"p2:we"}');
    expect(tester.widget<EditorScreen>(find.byType(EditorScreen)).reminderId, 'p2');
  });

  testWidgets('a prayer notification opens the Prayer screen', (tester) async {
    final s = await pumpApp(tester);
    s.reminders.prayer;
    await tap(tester, s, '{"r":"prayer:asr"}');
    expect(find.byType(PrayerScreen), findsOneWidget);
  });

  testWidgets('a ready-made moment opens its setup sheet over My reminders', (tester) async {
    final s = await pumpApp(tester);
    await tap(tester, s, '{"r":"t2"}');
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.byType(NiyahBottomSheet), findsOneWidget);
    expect(find.text('Remember Allah in your work'), findsWidgets);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('in Italian the sheet is in Italian', (tester) async {
    final s = await pumpApp(tester, lang: 'it');
    await tap(tester, s, '{"r":"t2"}');
    expect(find.text('Ricorda Allah nel tuo lavoro'), findsWidgets);
  });

  testWidgets('works from a pushed screen too', (tester) async {
    final s = await pumpApp(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.location);
    await tester.pumpAndSettle();
    expect(find.byType(LocationScreen), findsOneWidget);
    await tap(tester, s, '{"r":"p1"}');
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byType(LocationScreen), findsNothing);
  });

  testWidgets('the tap that launched the app is handled after the first frame', (tester) async {
    final services = AppServices.fake();
    (services.notifications as FakeNotificationService).tappedPayload.value = '{"r":"p1"}';
    await pumpApp(tester, services: services);
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets('refresh notice, deleted reminder or bad payload: stay where you are', (tester) async {
    final s = await pumpApp(tester);
    for (final payload in ['{"r":"_refresh"}', '{"r":"gone"}', 'oops']) {
      await tap(tester, s, payload);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(s.notifications.tappedPayload.value, isNull);
    }
  });
}
