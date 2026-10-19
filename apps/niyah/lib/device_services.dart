import 'app_scope.dart';
import 'data/sqlite/core_prayer_repository.dart';
import 'data/sqlite/niyah_database.dart';
import 'data/sqlite/prefs_settings_store.dart';
import 'data/sqlite/schedule_source.dart';
import 'data/sqlite/sqlite_reminder_repository.dart';
import 'data/sqlite/sqlite_template_repository.dart';
import 'notifications/local_notification_service.dart';

/// SQLite repositories and real local notifications (Android and iOS).
Future<AppServices?> deviceServices() async {
  final db = await NiyahDatabase.open();
  final settings = PrefsSettingsStore();
  return AppServices(
    reminders: SqliteReminderRepository(db),
    templates: SqliteTemplateRepository(db),
    prayers: CorePrayerRepository(),
    settings: settings,
    notifications: LocalNotificationService(inputs: ScheduleSource(db, settings)),
  );
}
