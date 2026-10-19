import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';

/// One destination of the [NiyahNavBar].
class NiyahNavItem {
  final String icon;
  final String label;
  const NiyahNavItem({required this.icon, required this.label});
}

/// Bottom tab bar: `surface` with a top border, equal columns, 24 px icon over
/// an 11.5 px label. The current item is `primaryInk` and bold.
class NiyahNavBar extends StatelessWidget {
  const NiyahNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.semanticLabel,
  });

  final List<NiyahNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Name of the navigation landmark (`aria-label="Main"`).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final bottom = math.max(22.0, MediaQuery.paddingOf(context).bottom);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottom),
          child: SizedBox(
            height: 53,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: _item(c, items[i], i == currentIndex, () => onTap(i))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(NiyahColors c, NiyahNavItem item, bool active, VoidCallback onTap) {
    final color = active ? c.primaryInk : c.text2;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NiyahIcon(item.icon, size: 24, strokeWidth: active ? 1.8 : 1.6, color: color),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: NiyahText.sans(11.5, weight: active ? FontWeight.w700 : FontWeight.w500, color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
