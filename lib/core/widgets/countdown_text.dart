import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Ticks once a second and renders a [Duration] as `HH:MM:SS`. The remaining
/// time is pulled from [remaining] each tick so it stays correct across the
/// day boundary. Reused by the daily next-word box, the starter-pack banner and
/// the streak-repair offer. Timer created in `initState`, disposed in `dispose`.
class CountdownText extends StatefulWidget {
  const CountdownText({required this.remaining, this.style, super.key});

  final Duration Function() remaining;
  final TextStyle? style;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Duration _left = widget.remaining();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = widget.remaining());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String format(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(clamped.inHours);
    final m = two(clamped.inMinutes.remainder(60));
    final s = two(clamped.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      format(_left),
      style: widget.style ?? AppTextStyles.headline.copyWith(fontSize: 32),
    );
  }
}
