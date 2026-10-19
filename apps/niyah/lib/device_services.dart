import 'dart:ui' show Locale, PlatformDispatcher;

import 'app_scope.dart';
import 'data/geolocator_location_service.dart';
import 'data/sqlite/core_prayer_repository.dart';
import 'data/sqlite/niyah_database.dart';
import 'data/sqlite/prefs_settings_store.dart';
import 'data/sqlite/schedule_source.dart';
import 'data/sqlite/sqlite_city_repository.dart';
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
    prayers: CorePrayerRepository(settings),
    settings: settings,
    notifications: LocalNotificationService(
      inputs: ScheduleSource(db, settings),
      // Notification texts follow the app language chosen in Settings.
      locale: () {
        final code = settings.languageCode;
        return code == null ? PlatformDispatcher.instance.locale : Locale(code);
      },
    ),
    cities: SqliteCityRepository(db),
    location: GeolocatorLocationService(),
  );
}
