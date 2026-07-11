import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A self-contained confetti burst for the win choreography (motion spec: "Win
/// → confetti burst"). Bumping [trigger] fires a ~1.8s fall of festive paper
/// rendered by a [CustomPainter] — no external Lottie asset or extra package.
///
/// Drop it as the top child of a [Stack] (it is a `Positioned.fill`); it paints
/// nothing while idle and never intercepts touches.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({required this.trigger, super.key});

  final ValueListenable<int> trigger;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  final math.Random _random = math.Random();
  List<_Confetto> _pieces = const [];
  late int _last = widget.trigger.value;

  static const List<Color> _palette = [
    AppColors.coin,
    AppColors.correct,
    AppColors.gem,
    AppColors.telegram,
    AppColors.present,
    AppColors.fire,
    AppColors.goldBright,
  ];

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_onTrigger);
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_onTrigger);
      widget.trigger.addListener(_onTrigger);
      _last = widget.trigger.value;
    }
  }

  void _onTrigger() {
    if (widget.trigger.value == _last) return;
    _last = widget.trigger.value;
    _pieces = List.generate(90, (_) => _Confetto.random(_random, _palette));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_onTrigger);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating || _pieces.isEmpty) {
              return const SizedBox.expand();
            }
            return CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_pieces, _controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _Confetto {
  _Confetto({
    required this.startX,
    required this.drift,
    required this.sway,
    required this.phase,
    required this.delay,
    required this.width,
    required this.height,
    required this.spin,
    required this.color,
  });

  final double startX; // 0..1 of width
  final double drift; // horizontal travel, fraction of width
  final double sway; // sway amplitude, fraction of width
  final double phase;
  final double delay; // 0..0.25 stagger
  final double width;
  final double height;
  final double spin;
  final Color color;

  factory _Confetto.random(math.Random r, List<Color> palette) => _Confetto(
    startX: r.nextDouble(),
    drift: (r.nextDouble() - 0.5) * 0.3,
    sway: 0.02 + r.nextDouble() * 0.05,
    phase: r.nextDouble() * math.pi * 2,
    delay: r.nextDouble() * 0.25,
    width: 6 + r.nextDouble() * 6,
    height: 8 + r.nextDouble() * 8,
    spin: (r.nextDouble() - 0.5) * 12,
    color: palette[r.nextInt(palette.length)],
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Confetto> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final span = 1 - p.delay;
      final local = ((progress - p.delay) / span).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final x = (p.startX + p.drift * local) * size.width +
          math.sin(local * math.pi * 4 + p.phase) * p.sway * size.width;
      final y = -0.08 * size.height + local * size.height * 1.18;
      final opacity = local < 0.82 ? 1.0 : (1 - local) / 0.18;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + local * p.spin);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.width,
          height: p.height,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress || old.pieces != pieces;
}
