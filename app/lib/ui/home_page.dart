import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'widgets.dart';

/// Home quasi vuota (architettura §2.3): nessun conteggio, nessun "prossimo
/// promemoria", nessuno storico.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NiyahPage(
      children: [
        const NiyahHeader(),
        const SizedBox(height: NiyahSpace.m),
        IslamicCard(
          icon: Icons.notifications_none,
          title: l.navNotifications,
          body: l.homeNotificationsBody,
          onTap: () => onNavigate(1),
        ),
        const SizedBox(height: NiyahSpace.m),
        IslamicCard(
          icon: Icons.explore_outlined,
          title: l.navStoPer,
          body: l.homeStoPerBody,
          onTap: () => onNavigate(2),
        ),
        const SizedBox(height: NiyahSpace.m),
        IslamicCard(
          icon: Icons.settings_outlined,
          title: l.navSettings,
          body: l.homeSettingsBody,
          onTap: () => onNavigate(3),
        ),
      ],
    );
  }
}
