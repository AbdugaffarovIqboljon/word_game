import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Filled secondary button (e.g. "Stories", "Nusxa"): surface-2 fill, hairline
/// border, radius 12 (component_spec (c)).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 46,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.chipR,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.chipR,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.chipR,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.text2),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outline secondary button (e.g. "Mashq qilish"): transparent fill, green
/// border, lighter green text (component_spec (c) — text uses `successBright`,
/// border uses `correct`; intentional contrast).
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.chipR,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.chipR,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.chipR,
            border: Border.all(color: AppColors.correct, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.successBright),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  color: AppColors.successBright,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
