import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/app.dart';
import 'package:niyah/app_scope.dart';
import 'package:niyah/core/theme/niyah_theme.dart';
import 'package:niyah/data/fake/fake_repositories.dart';
import 'package:niyah/data/models.dart';
import 'package:niyah/data/repositories.dart';
import 'package:niyah/l10n/app_localizations.dart';

/// Loads the bundled fonts so layout tests measure real glyphs.
Future<void> loadNiyahFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('Amiri', ['Amiri-Regular.ttf', 'Amiri-Bold.ttf']);
  await load('PlusJakartaSans', ['PlusJakartaSans-VariableFont_wght.ttf']);
}

/// Sets the test view to a 390×844 phone with the given language, theme and
/// text scale; everything is reset at the end of the test.
void setPhone(
  WidgetTester tester, {
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
  Size size = const Size(390, 844),
}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.platformDispatcher.localesTestValue = [Locale(lang)];
  tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

/// Pumps the whole app (real router and shell) on in-memory services.
/// [dark] picks the Dark theme in the app's settings (the app does not
/// follow the phone) and also sets the phone to dark.
Future<AppServices> pumpApp(
  WidgetTester tester, {
  AppServices? services,
  String lang = 'en',
  bool dark = false,
  double textScale = 1,
}) async {
  setPhone(tester, lang: lang, dark: dark, textScale: textScale);
  final s = services ?? AppServices.fake();
  await s.init();
  if (dark) await s.settings.setTheme(AppTheme.dark);
  await tester.pumpWidget(NiyahApp(services: s));
  await tester.pumpAndSettle();
  return s;
}

/// Pumps one widget inside a themed, localized [MaterialApp].
Future<void> pumpWidgetIn(
  WidgetTester tester,
  Widget child, {
  String lang = 'en',
  bool dark = false,
  AppServices? services,
}) async {
  await tester.pumpWidget(
    AppScope(
      services: services ?? AppServices.fake(),
      child: MaterialApp(
        theme: NiyahTheme.light(),
        darkTheme: NiyahTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Notification fake that records calls.
class RecordingNotifications extends FakeNotificationService {
  int permissionRequests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;
}

/// [AppServices.fake] with a [RecordingNotifications] and optional reminders,
/// settings (e.g. `FakeSettingsStore(location: null)`) and location service.
AppServices fakeServices({
  RecordingNotifications? notifications,
  FakeReminderRepository? reminders,
  SettingsStore? settings,
  LocationService? location,
}) {
  final base = AppServices.fake(settings: settings);
  return AppServices(
    reminders: reminders ?? base.reminders,
    templates: base.templates,
    prayers: base.prayers,
    settings: base.settings,
    notifications: notifications ?? RecordingNotifications(),
    cities: base.cities,
    location: location ?? base.location,
  );
}
