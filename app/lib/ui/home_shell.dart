import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'my_notifications_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';

/// Barra di navigazione inferiore con due voci: le notifiche create
/// dall'utente e quelle standard. Le Impostazioni non stanno nella barra:
/// si aprono dall'icona in alto.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [MyNotificationsPage(), StandardNotificationsPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.edit_notifications_outlined),
            selectedIcon: const Icon(Icons.edit_notifications),
            label: l.navNotifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_none),
            selectedIcon: const Icon(Icons.notifications),
            label: l.navStandard,
          ),
        ],
      ),
    );
  }
}

/// Icona delle Impostazioni nella barra in alto di ogni scheda.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: AppLocalizations.of(context).navSettings,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }
}
