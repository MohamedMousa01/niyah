import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/widgets/widgets.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';
import 'package:niyah/features/add_reminder/add_reminder_screen.dart';
import 'package:niyah/features/home/home_screen.dart';
import 'package:niyah/router.dart';

import '../../core/harness.dart';

/// Pumps the app and pushes "Add a reminder".
Future<AppServices> openAdd(
  WidgetTester tester, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  final s = await pumpApp(tester, services: services, lang: lang, dark: dark, textScale: textScale);
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.add);
  await tester.pumpAndSettle();
  expect(find.byType(AddReminderScreen), findsOneWidget);
  return s;
}

final addList = find.descendant(of: find.byType(AddReminderScreen), matching: find.byType(Scrollable));

/// Scrolls "Add a reminder" to the row titled [title] and opens its sheet.
Future<void> openTemplate(WidgetTester tester, String title) async {
  // From the top: rows scrolled far past are no longer built.
  await tester.drag(addList, const Offset(0, 20000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(title), 200, scrollable: addList);
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  expect(find.byType(NiyahBottomSheet), findsOneWidget);
}

/// A [TapArea] (stepper button) by its label: "Hour later", "Earlier"…
Finder tapArea(String label) => find.byWidgetPredicate((w) => w is TapArea && w.semanticLabel == label);

/// The template row whose tap target is announced as [label].
Finder rowLabelled(String label) => find.byWidgetPredicate((w) => w is ReminderRow && w.semanticLabel == label);

/// Day chip [i] (0 = Monday) of the sheet's days selector.
Finder dayChip(int i) =>
    find.descendant(of: find.byType(DaysSelector), matching: find.byType(GestureDetector)).at(i);

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The CTA of the open sheet.
PrimaryButton cta(WidgetTester tester) => tester.widget<PrimaryButton>(
  find.descendant(of: find.byType(NiyahBottomSheet), matching: find.byType(PrimaryButton)),
);

/// Records exact-alarm requests too.
class AlarmRecordingNotifications extends RecordingNotifications {
  int exactAlarmRequests = 0;

  @override
  Future<bool> ensureExactAlarms() async {
    exactAlarmRequests++;
    return true;
  }
}

/// [FakeTemplateRepository] limited to [groups].
class OnlyGroupsTemplates implements TemplateRepository {
  OnlyGroupsTemplates(this.groups);

  final Set<TemplateGroup> groups;
  final _base = FakeTemplateRepository();

  @override
  Future<void> init() async {}

  @override
  List<TemplateItem> templates(String languageCode) =>
      [for (final t in _base.templates(languageCode)) if (groups.contains(t.group)) t];

  @override
  TemplateItem? byId(String id, String languageCode) => _base.byId(id, languageCode);
}

/// Fake services with every piece replaceable.
AppServices addServices({
  NotificationService? notifications,
  TemplateRepository? templates,
  List<ReminderItem>? reminders,
}) {
  final base = AppServices.fake();
  return AppServices(
    reminders: reminders == null ? base.reminders : FakeReminderRepository(initial: reminders),
    templates: templates ?? base.templates,
    prayers: base.prayers,
    settings: base.settings,
    notifications: notifications ?? RecordingNotifications(),
  );
}
