import 'app_scope.dart';

/// Web: no SQLite or local notifications, so the app uses the in-memory services.
Future<AppServices?> deviceServices() async => null;
