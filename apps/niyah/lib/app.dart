import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'core/theme/niyah_theme.dart';
import 'l10n/app_localizations.dart';
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
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: NiyahTheme.light(),
        darkTheme: NiyahTheme.dark(),
        themeMode: ThemeMode.system,
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
      ),
    );
  }
}
