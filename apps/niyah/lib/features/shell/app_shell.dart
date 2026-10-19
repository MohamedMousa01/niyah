import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/niyah_icons.dart';
import '../../core/widgets/niyah_nav_bar.dart';
import '../../l10n/app_localizations.dart';

/// The three tabs (Home, Reminders, Settings) above the [NiyahNavBar].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.niyah.bg,
      body: shell,
      bottomNavigationBar: NiyahNavBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          NiyahNavItem(icon: NiyahIcons.home, label: l.navHome),
          NiyahNavItem(icon: NiyahIcons.bell, label: l.navReminders),
          NiyahNavItem(icon: NiyahIcons.sliders, label: l.navSettings),
        ],
      ),
    );
  }
}
