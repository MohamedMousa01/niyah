import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/niyah_database.dart';
import 'services/notification_gateway.dart';
import 'state/app_controller.dart';
import 'state/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();

  // Solo lavoro locale e istantaneo prima del primo frame (architettura §11).
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs, deviceLanguage: PlatformDispatcher.instance.locale.languageCode);
  final database = await NiyahDatabase.open();
  final controller = AppController(settings: settings, database: database, gateway: LocalNotificationGateway());

  runApp(NiyahApp(controller: controller));
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Plus Jakarta Sans', 'assets/fonts/OFL-PlusJakartaSans.txt'),
      ('IBM Plex Sans Arabic', 'assets/fonts/OFL-IBMPlexSansArabic.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(file));
    }
  });
}
