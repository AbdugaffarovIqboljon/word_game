import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/app_haptics.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_text_styles.dart';

/// A single tappable keyboard key. Fixed 50px height, 7px radius, key-bevel
/// shadow. Press feedback: scales to 0.95 over 90ms and springs back
/// (component_spec (a) / decisions §6). Colors and label are resolved by the
/// caller so this widget stays state-agnostic.
///
/// Background/foreground color changes animate over 200ms; passing a [fadeDelay]
/// staggers the start of that fade, which the clean-keyboard hint uses to fade a
/// batch of keys to their absent color 60ms apart (WS3 / audit clean-hint fix).
///
/// When [icon] is supplied the key renders that glyph instead of [label] — the
/// ENTER key uses the ↵ corner-down-left icon, mirroring the ⌫ backspace glyph
/// (component_spec (a)); [label] is still passed for the semantics tooltip.
class KeyboardKeyButton extends StatefulWidget {
  const KeyboardKeyButton({
    required this.label,
    required this.fontSize,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.icon,
    this.fadeDelay = Duration.zero,
    super.key,
  });

  final String label;
  final IconData? icon;
  final double fontSize;
  final Color background;
  final Color foreground;
  final Duration fadeDelay;

  /// Null disables the key (dimmed, non-tappable) — used by the tutorial's
  /// restricted keyboard.
  final VoidCallback? onTap;

  @override
  State<KeyboardKeyButton> createState() => _KeyboardKeyButtonState();
}

class _KeyboardKeyButtonState extends State<KeyboardKeyButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController _color = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  late Color _fromBg = widget.background;
  late Color _toBg = widget.background;
  late Color _fromFg = widget.foreground;
  late Color _toFg = widget.foreground;
  Timer? _fadeTimer;

  @override
  void didUpdateWidget(covariant KeyboardKeyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.background != _toBg || widget.foreground != _toFg) {
      // Animate from whatever is on screen now to the new target color.
      _fromBg = Color.lerp(_fromBg, _toBg, _color.value)!;
      _fromFg = Color.lerp(_fromFg, _toFg, _color.value)!;
      _toBg = widget.background;
      _toFg = widget.foreground;
      _color.value = 0;
      _fadeTimer?.cancel();
      if (widget.fadeDelay == Duration.zero) {
        _color.forward(from: 0);
      } else {
        _fadeTimer = Timer(widget.fadeDelay, () {
          if (mounted) _color.forward(from: 0);
        });
      }
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              _setPressed(true);
              AppHaptics.tap();
            },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _color,
          builder: (context, _) {
            final bg = Color.lerp(_fromBg, _toBg, _color.value)!;
            final fg = Color.lerp(_fromFg, _toFg, _color.value)!;
            return Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadii.keyR,
                boxShadow: AppShadows.keyBevel,
              ),
              child: widget.icon != null
                  ? Icon(
                      widget.icon,
                      size: widget.fontSize + 5,
                      color: fg,
                      semanticLabel: widget.label,
                    )
                  : Text(
                      widget.label,
                      style: AppTextStyles.tile(
                        widget.fontSize,
                        color: fg,
                      ).copyWith(fontWeight: FontWeight.w600, height: null),
                    ),
            );
          },
        ),
      ),
    );
  }
}
