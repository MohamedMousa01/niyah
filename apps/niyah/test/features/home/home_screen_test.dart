import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/features/home/home_screen.dart';
import 'package:niyah/features/reminders/reminders_screen.dart';
import 'package:niyah/features/settings/settings_screen.dart';

import '../../core/harness.dart';

void main() {
  setUpAll(loadNiyahFonts);

  for (final lang in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Home lays out without overflow ($lang, ${dark ? 'dark' : 'light'}, ×$scale)', (tester) async {
          await pumpApp(tester, lang: lang, dark: dark, textScale: scale);
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.text(HomeScreen.bismillah), findsOneWidget);
          expect(find.text('MyNiyah'), findsOneWidget);
          expect(find.text(lang == 'en' ? 'Renew your intention.' : 'Rinnova la tua intenzione.'), findsOneWidget);
          await tester.drag(find.byType(HomeScreen), const Offset(0, -1200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('next prayer line follows the prayer repository', (tester) async {
    final s = await pumpApp(tester);
    final next = s.prayers.nextPrayer(DateTime.now());
    if (next == null) {
      expect(find.text('Next prayer'), findsNothing);
    } else {
      expect(find.text('Next prayer'), findsOneWidget);
      expect(find.textContaining(' · '), findsWidgets);
    }
  });

  testWidgets('quick-access cards open the Reminders and Settings tabs', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Choose when Niyah reminds you'));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language, prayer times, quiet hours'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Language, prayer times and quiet hours will be here soon.'), findsOneWidget);
  });

  testWidgets('nav bar marks the current tab as selected', (tester) async {
    await pumpApp(tester, lang: 'it');
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      matchesSemantics(label: 'Home', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
    );
    await tester.tap(find.text('Impostazioni').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    handle.dispose();
  });
}
