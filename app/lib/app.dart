import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme/niyah_theme.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_page.dart';

class NiyahApp extends StatefulWidget {
  const NiyahApp({super.key, required this.controller, this.startServices = true});

  final AppController controller;

  /// Nei test dei widget le notifiche non si avviano.
  final bool startServices;

  @override
  State<NiyahApp> createState() => _NiyahAppState();
}

class _NiyahAppState extends State<NiyahApp> {
  @override
  void initState() {
    super.initState();
    if (widget.startServices) {
      // Prima il primo frame (Home subito), poi notifiche e riprogrammazione.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.controller.start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    return AppScope(
      controller: widget.controller,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final locale = Locale(settings.language);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: NiyahTheme.light(locale),
            darkTheme: NiyahTheme.dark(locale),
            home: settings.onboardingCompleted ? const HomeShell() : const OnboardingPage(),
          );
        },
      ),
    );
  }
}
