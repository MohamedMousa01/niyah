import 'package:flutter/material.dart';

/// A plain button with a fixed hit area (≥ 44 px) and a real semantics label.
/// The building block of the design's icon buttons (`all: unset` buttons).
class TapArea extends StatelessWidget {
  const TapArea({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.radius = 999,
    this.color,
  });

  /// Null disables the button.
  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;
  final double width;
  final double height;
  final double radius;

  /// Background fill (e.g. `chipOff` on the Prayer stepper).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: color ?? Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
