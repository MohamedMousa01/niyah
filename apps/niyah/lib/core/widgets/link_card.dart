import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';
import 'icon_tile.dart';
import 'niyah_card.dart';
import 'niyah_icons.dart';

/// Card that opens another screen: icon tile, title, subtitle and a chevron.
/// Default size is the Prayer card of My reminders (40 px tile, 15 px title);
/// [large] is the Home quick-access card (46 px tile, 16 px title).
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.icon,
    this.tone = IconTileTone.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.large = false,
  });

  final String icon;
  final IconTileTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return NiyahCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      padding: large
          ? const EdgeInsetsDirectional.fromSTEB(14, 16, 16, 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          large
              ? IconTile(icon: icon, tone: tone, size: 46, radius: 14, iconSize: 22)
              : IconTile(icon: icon, tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NiyahText.sans(large ? 16 : 15, weight: FontWeight.w600, color: c.text),
                ),
                SizedBox(height: large ? 2 : 3),
                Text(subtitle, style: NiyahText.sans(13.5, color: c.text2)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          NiyahIcon(NiyahIcons.chevronRight, size: 20, strokeWidth: 1.8, color: c.text3),
        ],
      ),
    );
  }
}
