import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Ticks once a second and renders a [Duration] as `HH:MM:SS`. The remaining
/// time is pulled from [remaining] each tick so it stays correct across the day
/// boundary. The changing seconds group gets a subtle per-tick opacity pulse.
///
/// When the remaining time hits zero, [onElapsed] fires once — the daily board
/// uses it to auto-refresh into the new day's puzzle without an app restart.
/// Reused by the daily next-word box, the starter-pack banner and the
/// streak-repair offer. Timer created in `initState`, disposed in `dispose`.
class CountdownText extends StatefulWidget {
  const CountdownText({
    required this.remaining,
    this.style,
    this.onElapsed,
    super.key,
  });

  final Duration Function() remaining;
  final TextStyle? style;
  final VoidCallback? onElapsed;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText>
    with SingleTickerProviderStateMixin {
  late Duration _left = widget.remaining();
  Timer? _timer;
  bool _elapsedFired = false;

  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..value = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = widget.remaining());
      _tick.forward(from: 0);
      if (!_elapsedFired && _left <= Duration.zero && widget.onElapsed != null) {
        _elapsedFired = true;
        _timer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onElapsed!.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppTextStyles.headline.copyWith(fontSize: 32);
    final clamped = _left.isNegative ? Duration.zero : _left;
    String two(int n) => n.toString().padLeft(2, '0');
    final head =
        '${two(clamped.inHours)}:${two(clamped.inMinutes.remainder(60))}:';
    final seconds = two(clamped.inSeconds.remainder(60));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(head, style: style),
        AnimatedBuilder(
          animation: _tick,
          builder: (context, child) => Opacity(
            // Fresh second fades in (0.5 → 1) for a soft ticking pulse.
            opacity: 0.5 + 0.5 * _tick.value,
            child: child,
          ),
          child: Text(seconds, style: style),
        ),
      ],
    );
  }
}
