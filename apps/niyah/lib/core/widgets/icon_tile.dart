import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';

/// Colour pair of an [IconTile].
enum IconTileTone {
  /// `tint` / `primaryInk`: template reminders, Settings card, sheet header.
  tint,

  /// `warmTint` / `warmInk`: reminders written by the user.
  warm,

  /// `primary` / `onPrimary`: prayer card, My reminders card.
  primary,
}

/// Rounded square holding a stroke icon. Defaults match the list rows
/// (40 px, 12 px radius, 20 px icon); Home cards use 46/14/22, the setup
/// sheet header 44/14/22.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = IconTileTone.tint,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
  });

  final String icon;
  final IconTileTone tone;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final (bg, fg) = switch (tone) {
      IconTileTone.tint => (c.tint, c.primaryInk),
      IconTileTone.warm => (c.warmTint, c.warmInk),
      IconTileTone.primary => (c.primary, c.onPrimary),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: NiyahIcon(icon, size: iconSize, color: fg),
    );
  }
}
