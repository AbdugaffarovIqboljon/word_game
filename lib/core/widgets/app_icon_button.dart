import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// 34×34 header icon button (component_spec (c)): surface-2 fill, hairline
/// border, radius 10. Optional [dot] draws an unread indicator (used by the
/// daily-chest gift button).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = AppColors.text2,
    this.iconSize = 18,
    this.dot = false,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final double iconSize;
  final bool dot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.iconButtonR,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.iconButtonR,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.iconButtonR,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );

    if (dot) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
