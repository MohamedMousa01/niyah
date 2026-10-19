import 'package:flutter/material.dart';

import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/back_header.dart';
import '../../l10n/app_localizations.dart';

/// Settings tab: a simple placeholder until the Settings milestone.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(24, NiyahInsets.top(context, 60), 24, 28),
        children: [
          ScreenTitle(title: l.settingsTitle),
          const SizedBox(height: 12),
          Text(l.settingsComingSoon, style: NiyahText.sans(15, height: 1.5, color: c.text2)),
        ],
      ),
    );
  }
}
