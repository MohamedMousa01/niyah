import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/core/theme/niyah_theme.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';

import 'harness.dart';

void main() {
  setUpAll(loadNiyahFonts);

  test('every template icon key has a drawing', () {
    for (final lang in ['en', 'it']) {
      for (final t in FakeTemplateRepository().templates(lang)) {
        expect(NiyahIcons.has(t.icon), isTrue, reason: t.icon);
      }
    }
    expect(NiyahIcons.elementsOf('unknown-key'), NiyahIcons.svg[NiyahIcons.fallback]);
  });

  test('themes expose the design tokens', () {
    expect(NiyahTheme.light().extension<NiyahColors>()!.bg, const Color(0xFFFAF8F3));
    expect(NiyahTheme.dark().extension<NiyahColors>()!.primaryInk, const Color(0xFF93CDB8));
    expect(NiyahTheme.dark().colorScheme.brightness, Brightness.dark);
  });

  testWidgets('NiyahSwitch: 54×44 hit area, switch semantics, toggles', (tester) async {
    var value = false;
    await pumpWidgetIn(
      tester,
      StatefulBuilder(
        builder: (context, setState) =>
            NiyahSwitch(value: value, semanticLabel: 'Fajr', onChanged: (v) => setState(() => value = v)),
      ),
    );
    expect(tester.getSize(find.byType(NiyahSwitch)), const Size(54, 44));
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(NiyahSwitch)),
      matchesSemantics(
        label: 'Fajr',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(NiyahSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(
      tester.getSemantics(find.byType(NiyahSwitch)),
      matchesSemantics(
        label: 'Fajr',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('TimeStepper: hour ±1 and minutes ±5, wrapping', (tester) async {
    var t = const LocalTime(23, 55);
    await pumpWidgetIn(
      tester,
      StatefulBuilder(
        builder: (context, setState) => TimeStepper(value: t, onChanged: (v) => setState(() => t = v)),
      ),
    );
    expect(find.text('23'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Hour later'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Minutes later'));
    await tester.pump();
    expect(t, const LocalTime(0, 0));
    await tester.tap(find.bySemanticsLabel('Hour earlier'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Minutes earlier'));
    await tester.pump();
    expect(t, const LocalTime(23, 55));
    expect(find.text('55'), findsOneWidget);
  });

  testWidgets('DaysSelector: narrow localized names, toggles mask bits', (tester) async {
    var mask = 31;
    await pumpWidgetIn(
      tester,
      lang: 'it',
      StatefulBuilder(
        builder: (context, setState) => DaysSelector(mask: mask, onChanged: (v) => setState(() => mask = v)),
      ),
    );
    expect(find.text('G'), findsOneWidget);
    expect(find.text('M'), findsNWidgets(2));
    await tester.tap(find.bySemanticsLabel('Domenica'));
    await tester.pump();
    expect(mask, 95);
    await tester.tap(find.bySemanticsLabel('Lunedì'));
    await tester.pump();
    expect(mask, 94);
  });

  testWidgets('PrayerChips toggle a set of prayers', (tester) async {
    var selected = {Prayer.fajr};
    await pumpWidgetIn(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PrayerChips(selected: selected, onChanged: (v) => setState(() => selected = v)),
      ),
    );
    await tester.tap(find.text('Asr'));
    await tester.pump();
    await tester.tap(find.text('Fajr'));
    await tester.pump();
    expect(selected, {Prayer.asr});
    expect(tester.getSize(find.ancestor(of: find.text('Asr'), matching: find.byType(Container)).first).height, 44);
  });

  testWidgets('SegmentedControl selects a value', (tester) async {
    var mode = 'before';
    await pumpWidgetIn(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SegmentedControl<String>(
          values: const ['before', 'adhan', 'after'],
          selected: mode,
          labelOf: (v) => v.toUpperCase(),
          onChanged: (v) => setState(() => mode = v),
        ),
      ),
    );
    await tester.tap(find.text('AFTER'));
    await tester.pump();
    expect(mode, 'after');
  });

  testWidgets('ValueStepper buttons, disabled at the end of the range', (tester) async {
    var minutes = 10;
    await pumpWidgetIn(
      tester,
      dark: true,
      StatefulBuilder(
        builder: (context, setState) => ValueStepper(
          label: 'How long before',
          value: '$minutes min',
          style: ValueStepperStyle.outlined,
          decrementLabel: 'Less time',
          incrementLabel: 'More time',
          onDecrement: minutes > 5 ? () => setState(() => minutes -= 5) : null,
          onIncrement: () => setState(() => minutes += 5),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Less time'));
    await tester.pump();
    expect(find.text('5 min'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Less time'));
    await tester.pump();
    expect(minutes, 5);
    await tester.tap(find.bySemanticsLabel('More time'));
    await tester.pump();
    expect(minutes, 10);
  });

  testWidgets('PrimaryButton: 54 px, disabled without a callback', (tester) async {
    var taps = 0;
    await pumpWidgetIn(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: 'Add reminder', onPressed: () => taps++),
          const PrimaryButton(label: 'Pick at least one day', onPressed: null),
          PrimaryButton.danger(label: 'Delete', onPressed: () {}, height: 52),
          PrimaryButton.outline(label: 'Turn it off instead', onPressed: () {}, height: 52),
          NiyahTextButton(label: 'Cancel', onPressed: () {}),
        ],
      ),
    );
    expect(tester.getSize(find.byType(PrimaryButton).first).height, 54);
    await tester.tap(find.text('Add reminder'));
    await tester.tap(find.text('Pick at least one day'));
    expect(taps, 1);
  });

  testWidgets('ReminderRow dims and says Off when disabled', (tester) async {
    var on = true;
    await pumpWidgetIn(
      tester,
      StatefulBuilder(
        builder: (context, setState) => NiyahCard(
          child: ReminderRow(
            icon: NiyahIcons.renew,
            title: 'Renew your intention',
            body: 'Begin your day.',
            when: '08:00 · Every day',
            enabled: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      ),
    );
    expect(find.text('08:00 · Every day'), findsOneWidget);
    await tester.tap(find.byType(NiyahSwitch));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.62);
  });

  testWidgets('bottom sheet, preview, header and ornament render in both themes', (tester) async {
    for (final dark in [false, true]) {
      await pumpWidgetIn(
        tester,
        dark: dark,
        Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BackHeader(title: 'Prayer reminders'),
              const NotificationPreview(title: 'Why am I doing this?', body: 'Pause.', time: '07:15'),
              const GeometricOrnament(size: 80, color: Colors.green),
              TextButton(
                onPressed: () => showNiyahSheet<void>(
                  context,
                  builder: (_) => const NiyahBottomSheet(
                    children: [
                      SheetHeader(icon: NiyahIcons.sunrise, title: 'After waking up'),
                      QuoteBox(body: '“Start your day with a clear intention.”'),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('HOW IT WILL ARRIVE'), findsOneWidget);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('After waking up'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('After waking up'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
