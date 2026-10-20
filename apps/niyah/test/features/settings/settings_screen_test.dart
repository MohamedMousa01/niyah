import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niyah/app.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/defaults.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';
import 'package:niyah/features/prayer/prayer_screen.dart';
import 'package:niyah/features/settings/location_screen.dart';
import 'package:niyah/features/settings/settings_screen.dart';
import 'package:niyah/router.dart';

import '../../core/harness.dart';

Future<AppServices> openSettings(
  WidgetTester tester, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  final s = await pumpApp(tester, services: services, lang: lang, dark: dark, textScale: textScale);
  await tester.tap(find.text(lang == 'en' ? 'Settings' : 'Impostazioni').last);
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
  return s;
}

final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;

final locationList = find.descendant(of: find.byType(LocationScreen), matching: find.byType(Scrollable)).first;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: settingsList);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder switchOf(String label) => find.byWidgetPredicate((w) => w is NiyahSwitch && w.semanticLabel.startsWith(label));

void main() {
  setUpAll(loadNiyahFonts);

  for (final lang in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final name = '($lang, ${dark ? 'dark' : 'light'}, ×$scale)';

        testWidgets('Settings lays out without overflow $name', (tester) async {
          final s = await openSettings(tester, lang: lang, dark: dark, textScale: scale);
          // Every optional row on: quiet hours times, the paused label.
          await s.settings.setQuietHours(const QuietHours(enabled: true));
          await s.settings.setPausedUntil(DateTime.now().add(const Duration(days: 3)));
          await s.settings.setAnchors(Defaults.anchors.withAnchor(Anchor.sleep, const LocalTime(23, 0), const LocalTime(23, 45)));
          await tester.pumpAndSettle();
          await tester.drag(settingsList, const Offset(0, -4000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Location screen and settings sheets lay out without overflow $name', (tester) async {
          final s = await openSettings(tester, lang: lang, dark: dark, textScale: scale);
          final l = lang == 'en';
          await tapVisible(tester, find.text(l ? 'Calculation method' : 'Metodo di calcolo'));
          await tester.drag(find.byType(NiyahBottomSheet), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(20, 20)); // scrim
          await tester.pumpAndSettle();

          await tapVisible(tester, find.text(l ? 'Your bedtime' : 'Il tuo orario per dormire'));
          await tester.tap(switchOf(l ? 'Different time on weekends' : 'Orario diverso nel weekend'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(20, 20));
          await tester.pumpAndSettle();

          (s.location as FakeLocationService).result = const PositionFailed(PositionProblem.deniedForever);
          GoRouter.of(tester.element(find.byType(SettingsScreen))).push(Routes.location);
          await tester.pumpAndSettle();
          await tester.tap(find.text(l ? 'Use my current location' : 'Usa la mia posizione attuale'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: locationList);
          await tester.enterText(find.byType(TextField), 'mi');
          await tester.pumpAndSettle();
          expect(find.text('Milan'), findsOneWidget);
          await tester.drag(locationList, const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('shows every setting with its current value', (tester) async {
    await openSettings(tester);
    expect(find.text('PRAYER TIMES'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Milan'), findsOneWidget);
    expect(find.text('Muslim World League'), findsOneWidget);
    expect(find.text('Asr time'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
    expect(find.text('Reminders can reach you at any time.'), findsOneWidget);
    expect(find.text('Pause all reminders'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Italiano'), 200, scrollable: settingsList);
    expect(find.text('MY DAY'), findsOneWidget);
    expect(find.text('Your wake-up time'), findsOneWidget);
    expect(find.text('06:40 · weekends 08:00'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('Phone language (English)'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  group('theme', () {
    Brightness brightness(WidgetTester tester) => Theme.of(tester.element(find.byType(SettingsScreen))).brightness;
    SystemUiOverlayStyle statusBar(WidgetTester tester) =>
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first).value;

    testWidgets('light by default, even when the phone is dark', (tester) async {
      setPhone(tester, dark: true);
      final s = AppServices.fake();
      await s.init();
      await tester.pumpWidget(NiyahApp(services: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(s.settings.theme, AppTheme.light);
      expect(brightness(tester), Brightness.light);
      expect(statusBar(tester), SystemUiOverlayStyle.dark); // dark icons on the light background
    });

    testWidgets('Dark switches the whole app and its status bar, Light switches back', (tester) async {
      final s = await openSettings(tester);
      await tapVisible(tester, find.text('Dark'));
      expect(s.settings.theme, AppTheme.dark);
      expect(brightness(tester), Brightness.dark);
      expect(statusBar(tester), SystemUiOverlayStyle.light);

      // Other screens follow too.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.text('MyNiyah'))).brightness, Brightness.dark);

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Light'));
      expect(s.settings.theme, AppTheme.light);
      expect(brightness(tester), Brightness.light);
    });

    testWidgets('Italian labels', (tester) async {
      await openSettings(tester, lang: 'it');
      await tester.scrollUntilVisible(find.text('Scuro'), 200, scrollable: settingsList);
      expect(find.text('ASPETTO'), findsOneWidget);
      expect(find.text('Chiaro'), findsOneWidget);
    });
  });

  testWidgets('Italian texts', (tester) async {
    await openSettings(tester, lang: 'it');
    expect(find.text('ORARI DI PREGHIERA'), findsOneWidget);
    expect(find.text('Lega del Mondo Musulmano'), findsOneWidget);
    expect(find.text("Orario dell'Asr"), findsOneWidget);
    expect(find.text('Non disturbare'), findsOneWidget);
    expect(find.text('Metti in pausa i promemoria'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Italiano'), 200, scrollable: settingsList);
    expect(find.text('LA MIA GIORNATA'), findsOneWidget);
    expect(find.text('Lingua del telefono (Italiano)'), findsOneWidget);
  });

  testWidgets('the language choice overrides the phone language, everywhere', (tester) async {
    final s = await openSettings(tester);
    await tapVisible(tester, find.text('Italiano'));
    expect(s.settings.languageCode, 'it');
    expect(find.text('Impostazioni'), findsWidgets); // title and tab
    await tester.scrollUntilVisible(find.text('ORARI DI PREGHIERA'), -200, scrollable: settingsList);
    expect(find.text('ORARI DI PREGHIERA'), findsOneWidget);

    await tester.tap(find.text('Promemoria').last);
    await tester.pumpAndSettle();
    expect(find.text('I miei promemoria'), findsOneWidget);

    await tester.tap(find.text('Impostazioni').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Lingua del telefono (English)'));
    expect(s.settings.languageCode, isNull);
    await tester.scrollUntilVisible(find.text('PRAYER TIMES'), -200, scrollable: settingsList);
    expect(find.text('PRAYER TIMES'), findsOneWidget);
  });

  testWidgets('method: pick one, the suggested one goes back to automatic', (tester) async {
    final s = await openSettings(tester);
    await tester.tap(find.text('Calculation method'));
    await tester.pumpAndSettle();
    expect(find.text('Suggested for your location'), findsOneWidget);
    await tester.tap(find.text('Egyptian General Authority of Survey'));
    await tester.pumpAndSettle();
    expect(s.settings.methodChoice, 'egyptian');
    expect(find.byType(NiyahBottomSheet), findsNothing);
    expect(find.text('Egyptian General Authority of Survey'), findsOneWidget);

    await tester.tap(find.text('Calculation method'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muslim World League'));
    await tester.pumpAndSettle();
    expect(s.settings.methodChoice, isNull);
    expect(s.settings.method, 'muslim_world_league');
  });

  testWidgets('Asr: Hanafi and back', (tester) async {
    final s = await openSettings(tester);
    await tester.tap(find.text('Hanafi'));
    await tester.pumpAndSettle();
    expect(s.settings.madhab, 'hanafi');
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    expect(s.settings.madhab, 'shafi');
  });

  testWidgets('quiet hours: switch on, change the start, the note follows', (tester) async {
    final s = await openSettings(tester);
    var changes = 0;
    s.settings.addListener(() => changes++);
    await tester.tap(switchOf('Quiet hours'));
    await tester.pumpAndSettle();
    expect(s.settings.quietHours.enabled, isTrue);
    expect(find.text('Reminders stay silent from 22:30 to 07:00.'), findsOneWidget);

    await tapVisible(tester, find.text('From'));
    expect(find.text('Quiet hours start'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Hour later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(s.settings.quietHours.start, const LocalTime(23, 30));
    expect(s.settings.quietHours.end, const LocalTime(7, 0));
    expect(find.text('Reminders stay silent from 23:30 to 07:00.'), findsOneWidget);

    // Closing the sheet without saving keeps the value.
    await tapVisible(tester, find.text('To'));
    await tester.tap(find.bySemanticsLabel('Hour later'));
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(s.settings.quietHours.end, const LocalTime(7, 0));

    await tester.ensureVisible(switchOf('Quiet hours'));
    await tester.pumpAndSettle();
    await tester.tap(switchOf('Quiet hours'));
    await tester.pumpAndSettle();
    expect(s.settings.quietHours.enabled, isFalse);
    expect(s.settings.quietHours.start, const LocalTime(23, 30)); // kept for next time
    expect(find.text('From'), findsNothing);
    expect(changes, 3); // every change notifies (main.dart reschedules)
  });

  testWidgets('pause: for a day, until turned back on, resume', (tester) async {
    final s = await openSettings(tester);
    await tapVisible(tester, find.text('Pause all reminders'));
    expect(find.text('Turn reminders back on'), findsNothing);
    await tester.tap(find.text('For 1 day'));
    await tester.pumpAndSettle();
    final until = s.settings.pausedUntil!;
    expect(until.difference(DateTime.now().toUtc()).inHours, inInclusiveRange(23, 24));
    expect(find.textContaining('Paused until'), findsOneWidget);

    await tapVisible(tester, find.text('Pause all reminders'));
    await tester.tap(find.text('Until I turn them back on'));
    await tester.pumpAndSettle();
    expect(s.settings.pausedUntil, SettingsStore.pausedForever);
    expect(find.text('Paused until you turn them back on'), findsOneWidget);

    await tapVisible(tester, find.text('Pause all reminders'));
    await tester.tap(find.text('Turn reminders back on'));
    await tester.pumpAndSettle();
    expect(s.settings.pausedUntil, isNull);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('My day: wake-up time with a weekend time', (tester) async {
    final s = await openSettings(tester);
    await tapVisible(tester, find.text('Your wake-up time'));
    expect(find.text('Every reminder set to “after waking up” follows this time.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Minutes later'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Weekend time later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(s.settings.anchors.wake, const LocalTime(6, 45));
    expect(s.settings.anchors.wakeWeekend, const LocalTime(8, 15));
    expect(s.settings.anchors.sleep, const LocalTime(22, 30));
    expect(find.text('06:45 · weekends 08:15'), findsOneWidget);

    await tapVisible(tester, find.text('Your bedtime'));
    await tester.tap(switchOf('Different time on weekends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(s.settings.anchors.sleepWeekend, const LocalTime(23, 30));
  });

  group('location', () {
    Future<AppServices> openLocation(WidgetTester tester, {AppServices? services, String lang = 'en'}) async {
      final s = await openSettings(tester, services: services, lang: lang);
      await tester.tap(find.text(lang == 'en' ? 'Location' : 'Posizione'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsOneWidget);
      return s;
    }

    testWidgets('search by Italian name, pick, back to Settings', (tester) async {
      final s = await openLocation(tester);
      expect(find.text('Now: Milan · Muslim World League'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'parigi');
      await tester.pumpAndSettle();
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('FR · Europe/Paris'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No city found'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Il Cairo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cairo'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsNothing);
      expect(s.settings.location!.name, 'Cairo');
      expect(s.settings.location!.timezone, 'Africa/Cairo');
      // The suggested method follows the new country.
      expect(find.text('Cairo'), findsOneWidget);
      expect(find.text('Egyptian General Authority of Survey'), findsOneWidget);
    });

    testWidgets('GPS: the nearest city names the rounded position', (tester) async {
      final s = await openLocation(tester);
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsNothing);
      final loc = s.settings.location!;
      expect((loc.name, loc.fromGps, loc.latitude, loc.longitude), ('Milan', true, 45.48, 9.23));
      expect(find.text('Near Milan'), findsOneWidget);
    });

    testWidgets('GPS problems are explained; "never" offers the settings', (tester) async {
      final location = FakeLocationService();
      final s = await openLocation(tester, services: fakeServices(location: location));
      for (final (problem, text) in [
        (PositionProblem.serviceOff, 'Location is off on this phone.'),
        (PositionProblem.denied, "MyNiyah can't use your location."),
        (PositionProblem.unavailable, "Your location couldn't be found."),
      ]) {
        location.result = PositionFailed(problem);
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
        expect(find.textContaining(text), findsOneWidget);
        expect(find.text('Open settings'), findsNothing);
      }
      location.result = const PositionFailed(PositionProblem.deniedForever);
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Location access is off for MyNiyah.'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      expect(location.settingsOpened, 1);

      location.result = const PositionFound(0, 0); // Gulf of Guinea
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No city found near you.'), findsOneWidget);
      expect(s.settings.location, FakeSettingsStore.sampleLocation); // unchanged
      expect(find.byType(LocationScreen), findsOneWidget);
    });

    testWidgets('without a location: Settings and the Prayer screen ask for one', (tester) async {
      final s = await openSettings(tester, services: fakeServices(settings: FakeSettingsStore(location: null)));
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('Prayer times need your location.'), findsOneWidget);
      expect(s.prayers.today, isNull);

      GoRouter.of(tester.element(find.byType(SettingsScreen))).push(Routes.prayer);
      await tester.pumpAndSettle();
      expect(find.byType(PrayerScreen), findsOneWidget);
      expect(find.text('Prayer times need your location.'), findsOneWidget);
      expect(find.text('05:58'), findsNothing);
      await tester.tap(find.text('Set your location'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rome');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rome'));
      await tester.pumpAndSettle();

      expect(find.byType(PrayerScreen), findsOneWidget);
      expect(find.text('Prayer times need your location.'), findsNothing);
      expect(find.text('05:58'), findsOneWidget);
      expect(find.text('Rome · Muslim World League'), findsOneWidget);
    });
  });
}
