import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'core/theme/niyah_theme.dart';
import 'data/models.dart';
import 'features/add_reminder/template_sheet.dart';
import 'l10n/app_localizations.dart';
import 'notifications/tap_target.dart';
import 'router.dart';

class NiyahApp extends StatefulWidget {
  const NiyahApp({super.key, required this.services});

  final AppServices services;

  @override
  State<NiyahApp> createState() => _NiyahAppState();
}

class _NiyahAppState extends State<NiyahApp> {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    widget.services.notifications.tappedPayload.addListener(_openTapped);
    // A tap that launched the app may have arrived before this listener.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTapped());
  }

  @override
  void dispose() {
    widget.services.notifications.tappedPayload.removeListener(_openTapped);
    _router.dispose();
    super.dispose();
  }

  /// Opens what a tapped notification is about: personal → editor,
  /// template → its setup sheet over My reminders, prayer → Prayer screen.
  void _openTapped() {
    if (!mounted || widget.services.notifications.tappedPayload.value == null) return;
    final payload = widget.services.notifications.takeTappedPayload();
    if (payload == null) return;
    final reminder = tappedReminder(payload, widget.services.reminders);
    if (reminder == null) return;
    switch (reminder.source) {
      case ReminderSource.personal:
        _router.go(Routes.edit(reminder.id));
      case ReminderSource.prayer:
        _router.go(Routes.prayer);
      case ReminderSource.template:
        final templateId = reminder.templateId;
        _router.go(Routes.reminders);
        if (templateId == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) showTemplateSheet(context, templateId);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    return AppScope(
      services: widget.services,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final language = settings.languageCode;
          final dark = settings.theme == AppTheme.dark;
          return MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            debugShowCheckedModeBanner: false,
            theme: NiyahTheme.light(),
            darkTheme: NiyahTheme.dark(),
            // The theme chosen in Settings (light by default), not the phone's.
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            // Status and navigation bar icons follow the app's theme, so they
            // stay readable when it differs from the phone's.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              child: child!,
            ),
            // The language chosen in Settings wins over the phone's.
            locale: language == null ? null : Locale(language),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (locale, supported) =>
                supported.firstWhere((l) => l.languageCode == locale?.languageCode, orElse: () => const Locale('en')),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
