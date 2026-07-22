import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tile_skin.dart';

/// Paints a skin's procedural board-area ambiance behind its [child] (WS4).
///
/// The pattern is deliberately low-contrast (≤6% opacity strokes) so the tiles
/// stay perfectly readable over it. It is wrapped in its own [RepaintBoundary]
/// and its painter's [SkinPatternPainter.shouldRepaint] only returns true when
/// the skin actually changes — so tile flips (which repaint the board's own
/// boundary) never repaint the background, and the painter allocates nothing
/// per frame. Standart is a pure pass-through (no extra layer).
class SkinBackground extends StatelessWidget {
  const SkinBackground({required this.skin, required this.child, super.key});

  final TileSkin skin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (skin.pattern == SkinPattern.none) return child;
    return RepaintBoundary(
      child: CustomPaint(
        painter: SkinPatternPainter(pattern: skin.pattern, tint: skin.accent),
        child: child,
      ),
    );
  }
}

/// Draws the four board ambiances. Static (never animated): a single paint per
/// size/skin change, so there is zero per-frame allocation during play.
class SkinPatternPainter extends CustomPainter {
  const SkinPatternPainter({required this.pattern, required this.tint});

  final SkinPattern pattern;
  final Color tint;

  // Opacity ceiling for every stroke/fill — keeps tiles readable (WS4 ≤6%).
  static const double _lineAlpha = 0.055;
  static const double _glowAlpha = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case SkinPattern.none:
        return;
      case SkinPattern.girih:
        _paintGirih(canvas, size);
      case SkinPattern.neonGrid:
        _paintNeonGrid(canvas, size);
      case SkinPattern.oltinShimmer:
        _paintOltinShimmer(canvas, size);
    }
  }

  /// Milliy — an interlaced girih lattice: a square grid crossed by both
  /// diagonals, forming the classic diamond-in-square Islamic motif.
  void _paintGirih(Canvas canvas, Size size) {
    const cell = 34.0;
    final paint = Paint()
      ..color = tint.withValues(alpha: _lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Diagonals across each cell weave the lattice into girih diamonds.
    for (var x = -size.height; x <= size.width; x += cell) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  /// Neon — a faint orthogonal grid with a soft top-down glow wash so the lines
  /// read as backlit rather than flat.
  void _paintNeonGrid(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: _glowAlpha),
            tint.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    const cell = 30.0;
    final line = Paint()
      ..color = tint.withValues(alpha: _lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  /// Oltin — a soft central radial shimmer plus a small arc flourish tucked in
  /// each corner.
  void _paintOltinShimmer(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide * 0.6;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: _glowAlpha),
            tint.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final flourish = Paint()
      ..color = tint.withValues(alpha: _lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const r = 26.0;
    // A quarter-arc opening inward from each corner.
    final corners = <(Offset, double)>[
      (Offset.zero, 0),
      (Offset(size.width, 0), math.pi / 2),
      (Offset(size.width, size.height), math.pi),
      (Offset(0, size.height), 3 * math.pi / 2),
    ];
    for (final (corner, start) in corners) {
      canvas.drawArc(
        Rect.fromCircle(center: corner, radius: r),
        start,
        math.pi / 2,
        false,
        flourish,
      );
    }
  }

  @override
  bool shouldRepaint(SkinPatternPainter old) =>
      old.pattern != pattern || old.tint != tint;
}
