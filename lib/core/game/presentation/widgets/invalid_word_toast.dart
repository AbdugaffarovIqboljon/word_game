import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_text_styles.dart';

/// Inverted light pill shown on an invalid word (component_spec (b)): white
/// background, dark text, 13/700, radius 8, toast shadow. Auto-dismisses after
/// 1.4s.
class InvalidWordToast extends StatelessWidget {
  const InvalidWordToast({required this.message, super.key});

  final String message;

  static const Duration _visibleFor = Duration(milliseconds: 1400);
  static const Duration _fade = Duration(milliseconds: 160);

  /// Shows the toast in the nearest [Overlay], floating [topOffset] from the top.
  static void show(
    BuildContext context, {
    required String message,
    double topOffset = 150,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: topOffset,
        left: 0,
        right: 0,
        child: _ToastFader(
          visibleFor: _visibleFor,
          fade: _fade,
          onDone: entry.remove,
          child: Center(child: InvalidWordToast(message: message)),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
          color: AppColors.text, // #F4F7FC light pill
          borderRadius: BorderRadius.all(Radius.circular(8)),
          boxShadow: AppShadows.toast,
        ),
        child: Text(
          message,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 13,
            color: AppColors.bg, // #0B1220 dark text
          ),
        ),
      ),
    );
  }
}

/// Fades its [child] in, holds for [visibleFor], fades out, then calls [onDone].
class _ToastFader extends StatefulWidget {
  const _ToastFader({
    required this.child,
    required this.visibleFor,
    required this.fade,
    required this.onDone,
  });

  final Widget child;
  final Duration visibleFor;
  final Duration fade;
  final VoidCallback onDone;

  @override
  State<_ToastFader> createState() => _ToastFaderState();
}

class _ToastFaderState extends State<_ToastFader> {
  double _opacity = 0;
  Timer? _holdTimer;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
    _holdTimer = Timer(widget.visibleFor, () {
      if (mounted) setState(() => _opacity = 0);
      _removeTimer = Timer(widget.fade, widget.onDone);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: widget.fade,
        child: widget.child,
      ),
    );
  }
}
