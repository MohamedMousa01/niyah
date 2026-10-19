import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_scope.dart';
import 'device_services_stub.dart' if (dart.library.io) 'device_services.dart';
import 'notifications/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  final services = (_isMobile ? await deviceServices() : null) ?? AppServices.fake();
  await services.init();
  runApp(NiyahApp(services: services));
  WidgetsBinding.instance.addPostFrameCallback((_) => _startBackground(services));
}

bool get _isMobile =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Work that must never delay the first frame (architettura §11).
void _startBackground(AppServices s) {
  final notifications = s.notifications;
  void reschedule() => unawaited(notifications.reschedule());
  unawaited(notifications.init().then((_) => reschedule()));
  // Every change to reminders or settings rebuilds the OS schedule.
  s.reminders.addListener(reschedule);
  s.settings.addListener(reschedule);
  // Back in the foreground: refresh the rolling window if it is getting old.
  if (notifications is LocalNotificationService) {
    AppLifecycleListener(onResume: () => unawaited(notifications.rescheduleIfStale()));
  }
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [('Amiri', 'OFL-Amiri.txt'), ('Plus Jakarta Sans', 'OFL-PlusJakartaSans.txt')]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
