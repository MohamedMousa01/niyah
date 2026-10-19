import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/features/add_reminder/add_reminder_screen.dart';
import 'package:niyah/features/editor/editor_screen.dart';

import '../../core/harness.dart';
import 'add_helpers.dart';

void main() {
  setUpAll(loadNiyahFonts);

  for (final lang in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Add a reminder lays out without overflow ($lang, ${dark ? 'dark' : 'light'}, ×$scale)', (
          tester,
        ) async {
          await openAdd(tester, lang: lang, dark: dark, textScale: scale);
          // Down to the last row, building every row on the way.
          final last = find.text(lang == 'en' ? 'Evening adhkar' : 'Adhkar della sera');
          await tester.scrollUntilVisible(last, 200, scrollable: addList);
          await tester.drag(addList, const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(last, findsOneWidget);
        });
      }
    }
  }

  testWidgets('shows the design content', (tester) async {
    await openAdd(tester);
    expect(find.text('Add a reminder'), findsOneWidget);
    expect(find.text('In your own words'), findsOneWidget);
    expect(find.text('Write what you want to be reminded of…'), findsOneWidget);
    expect(find.text('You choose the words, the time and the days.'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('Pick a ready-made moment'), findsOneWidget);
    expect(find.text('AROUND PRAYER'), findsOneWidget);
    expect(find.text('Before each prayer'), findsOneWidget);
    expect(find.text('“Prepare your heart for the prayer.”'), findsOneWidget);
    expect(find.text('10 min before adhan · every prayer'), findsOneWidget);
    expect(find.text('15 min after adhan · every prayer'), findsOneWidget);
    expect(find.text('YOUR DAY'), findsOneWidget);
    expect(find.text('At your wake-up time · 06:40 · weekends 08:00'), findsOneWidget);
  });

  testWidgets('Italian texts', (tester) async {
    await openAdd(tester, lang: 'it');
    expect(find.text('Aggiungi un promemoria'), findsOneWidget);
    expect(find.text('Con parole tue'), findsOneWidget);
    expect(find.text('INTORNO ALLA PREGHIERA'), findsOneWidget);
    expect(find.text('Prima di ogni preghiera'), findsOneWidget);
    expect(find.text('«Prepara il cuore alla preghiera.»'), findsOneWidget);
    expect(find.text('10 min prima dell\'adhan · ogni preghiera'), findsOneWidget);
    expect(find.text('Tutti'), findsOneWidget);
  });

  testWidgets('filters show one group at a time', (tester) async {
    await openAdd(tester);
    final filters = tester.widget<SegmentedControl<TemplateGroup?>>(find.byType(SegmentedControl<TemplateGroup?>));
    expect(filters.values, [null, TemplateGroup.prayer, TemplateGroup.daily, TemplateGroup.dhikr]);
    expect(find.text('Weekly'), findsNothing);

    await tester.tap(find.text('Dhikr'));
    await tester.pumpAndSettle();
    expect(find.text('DHIKR'), findsOneWidget);
    expect(find.text('Morning adhkar'), findsOneWidget);
    expect(find.text('AROUND PRAYER'), findsNothing);
    expect(find.text('YOUR DAY'), findsNothing);

    await tester.tap(find.text('Prayer'));
    await tester.pumpAndSettle();
    expect(find.text('AROUND PRAYER'), findsOneWidget);
    expect(find.text('DHIKR'), findsNothing);

    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR DAY'), findsOneWidget);
    expect(find.text('AROUND PRAYER'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('AROUND PRAYER'), findsOneWidget);
    expect(find.text('YOUR DAY'), findsOneWidget);
  });

  testWidgets('groups without templates and their filters are hidden', (tester) async {
    await openAdd(tester, services: addServices(templates: OnlyGroupsTemplates({TemplateGroup.daily})));
    final filters = tester.widget<SegmentedControl<TemplateGroup?>>(find.byType(SegmentedControl<TemplateGroup?>));
    expect(filters.values, [null, TemplateGroup.daily]);
    expect(find.text('Prayer'), findsNothing);
    expect(find.text('Dhikr'), findsNothing);
    expect(find.text('AROUND PRAYER'), findsNothing);
    expect(find.text('YOUR DAY'), findsOneWidget);
  });

  testWidgets('badges and "when" lines follow what the user added', (tester) async {
    final s = await openAdd(tester);
    // Added (sample reminder t2) vs not added.
    expect(rowLabelled('Change Remember Allah in your work'), findsOneWidget);
    expect(rowLabelled('Set up and add Intention before studying'), findsOneWidget);
    expect(find.descendant(of: rowLabelled('Change Remember Allah in your work'), matching: find.byWidgetPredicate((w) => w is NiyahIcon && w.name == NiyahIcons.check)), findsOneWidget);
    expect(find.descendant(of: rowLabelled('Set up and add Intention before studying'), matching: find.byWidgetPredicate((w) => w is NiyahIcon && w.name == NiyahIcons.plus)), findsOneWidget);

    // The saved schedule wins over the template default.
    final t2 = s.reminders.byId('t2')!;
    await s.reminders.save(t2.copyWith(schedule: const TimeSchedule(LocalTime(10, 30), daysMask: 0x60)));
    await tester.pumpAndSettle();
    expect(find.text('10:30 · Weekends'), findsOneWidget);
  });

  testWidgets('"In your own words" opens the editor', (tester) async {
    await openAdd(tester);
    await tester.tap(find.text('Write what you want to be reminded of…'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.widget<EditorScreen>(find.byType(EditorScreen)).reminderId, isNull);
  });

  testWidgets('back returns to the previous screen', (tester) async {
    await openAdd(tester);
    await tester.tap(tapArea('Back to My reminders'));
    await tester.pumpAndSettle();
    expect(find.byType(AddReminderScreen), findsNothing);
  });
}
