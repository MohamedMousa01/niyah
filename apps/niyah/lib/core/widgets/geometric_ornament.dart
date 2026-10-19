import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The eight-pointed star of the design, drawn on a 100×100 grid:
/// two squares rotated 45° around the centre, a circle, and two smaller
/// squares. [simple] draws only the two large squares (26–74), as in the
/// app icon of the notification preview.
class GeometricOrnament extends StatelessWidget {
  const GeometricOrnament({
    super.key,
    this.size = 260,
    required this.color,
    this.strokeWidth = 0.8,
    this.simple = false,
  });

  /// The app-icon variant: two squares, stroke 7 (in grid units).
  const GeometricOrnament.icon({super.key, this.size = 24, required this.color}) : strokeWidth = 7, simple = true;

  final double size;
  final Color color;

  /// In grid units (1/100 of [size]).
  final double strokeWidth;
  final bool simple;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _OrnamentPainter(color, strokeWidth, simple)),
  );
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter(this.color, this.strokeWidth, this.simple);

  final Color color;
  final double strokeWidth;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const centre = Offset(50, 50);

    void starOfSquares(double half) {
      final square = Rect.fromCenter(center: centre, width: half * 2, height: half * 2);
      canvas.drawRect(square, paint);
      canvas.save();
      canvas.translate(50, 50);
      canvas.rotate(math.pi / 4);
      canvas.translate(-50, -50);
      canvas.drawRect(square, paint);
      canvas.restore();
    }

    if (simple) {
      starOfSquares(24);
      return;
    }
    starOfSquares(30);
    canvas.drawCircle(centre, 18, paint);
    starOfSquares(15);
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.simple != simple;
}
