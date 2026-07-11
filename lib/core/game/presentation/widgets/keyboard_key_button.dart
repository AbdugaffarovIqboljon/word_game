import 'package:flutter/material.dart';

import '../../../services/app_haptics.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_text_styles.dart';

/// A single tappable keyboard key. Fixed 50px height, 7px radius, key-bevel
/// shadow. Press feedback: scales to 0.95 over 90ms and springs back
/// (component_spec (a) / decisions §6). Colors/label/border are resolved by the
/// caller so this widget stays state-agnostic.
class KeyboardKeyButton extends StatefulWidget {
  const KeyboardKeyButton({
    required this.label,
    required this.fontSize,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
    super.key,
  });

  final String label;
  final double fontSize;
  final Color background;
  final Color foreground;
  final Border? border;
  final VoidCallback onTap;

  @override
  State<KeyboardKeyButton> createState() => _KeyboardKeyButtonState();
}

class _KeyboardKeyButtonState extends State<KeyboardKeyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
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
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background,
            border: widget.border,
            borderRadius: AppRadii.keyR,
            boxShadow: AppShadows.keyBevel,
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.tile(
              widget.fontSize,
              color: widget.foreground,
            ).copyWith(fontWeight: FontWeight.w600, height: null),
          ),
        ),
      ),
    );
  }
}
