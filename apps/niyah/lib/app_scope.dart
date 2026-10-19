import 'package:flutter/widgets.dart';

import 'data/fake/fake_repositories.dart';
import 'data/repositories.dart';

/// Everything the screens need, created once in `main.dart`.
class AppServices {
  final ReminderRepository reminders;
  final TemplateRepository templates;
  final PrayerRepository prayers;
  final SettingsStore settings;
  final NotificationService notifications;

  const AppServices({
    required this.reminders,
    required this.templates,
    required this.prayers,
    required this.settings,
    required this.notifications,
  });

  /// In-memory services: widget tests and the web preview.
  factory AppServices.fake() => AppServices(
        reminders: FakeReminderRepository(),
        templates: FakeTemplateRepository(),
        prayers: FakePrayerRepository(),
        settings: FakeSettingsStore(),
        notifications: FakeNotificationService(),
      );

  Future<void> init() async {
    await Future.wait([reminders.init(), templates.init(), prayers.init(), settings.init()]);
  }
}

/// Hands [AppServices] down the tree: `AppScope.of(context).reminders`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
