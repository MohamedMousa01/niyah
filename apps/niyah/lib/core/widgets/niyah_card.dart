import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';

/// Surface card: 20 px radius, 1 px border. With [onTap] the whole card is a
/// button (ink ripple clipped to the radius).
class NiyahCard extends StatelessWidget {
  const NiyahCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.semanticLabel,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Replaces the children's semantics with one label (for tappable cards).
  final String? semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: c.border),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }
    if (semanticLabel != null) {
      content = Semantics(button: onTap != null, label: semanticLabel, onTap: onTap, excludeSemantics: true, child: content);
    }
    return Material(color: c.surface, shape: shape, clipBehavior: Clip.antiAlias, child: content);
  }
}

/// 1 px divider line between rows of a card (`border-top: 1px solid var(--divider)`).
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.niyah.divider,
    child: const SizedBox(height: 1, width: double.infinity),
  );
}
