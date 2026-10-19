import 'package:flutter/material.dart';

import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/niyah_icons.dart';
import '../../l10n/app_localizations.dart';

/// Discreet row shown when the OS blocks notifications:
/// "Notifications are off · Open settings".
class NotificationsOffRow extends StatelessWidget {
  const NotificationsOffRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l.notificationsOff}. ${l.openSettings}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.warmTint,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                NiyahIcon(NiyahIcons.bell, size: 18, strokeWidth: 1.7, color: c.warmInk),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.notificationsOff,
                          style: NiyahText.sans(13.5, color: c.text),
                        ),
                        TextSpan(
                          text: '  ·  ',
                          style: NiyahText.sans(13.5, color: c.text3),
                        ),
                        TextSpan(
                          text: l.openSettings,
                          style: NiyahText.sans(13.5, weight: FontWeight.w600, color: c.primaryInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
