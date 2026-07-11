import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A rounded rectangle with a dashed border — used for the share screen's
/// `CROSS-PROMO SLOT` placeholder (screen_inventory §2).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    required this.child,
    this.color = AppColors.border,
    this.radius = 16,
    this.dashWidth = 6,
    this.dashGap = 5,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        radius: radius,
        dashWidth: dashWidth,
        dashGap: dashGap,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}
