import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact "Mashq" pill below the board → practice (decisions §2). Carries the
/// active skin's [accent] tint on its icon and border (WS4); Standart passes the
/// neutral default so it reads unchanged.
class MashqPill extends StatelessWidget {
  const MashqPill({required this.onTap, this.accent, super.key});

  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.successBright;
    final isNeutral = accent == null || accent == AppColors.textSub;
    final iconColor = isNeutral ? AppColors.successBright : tint;
    final borderColor =
        isNeutral ? AppColors.border : tint.withValues(alpha: 0.5);
    return Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillR,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.practice, size: 15, color: iconColor),
              const SizedBox(width: 7),
              Text(
                LocaleKeys.dailyPracticePill.tr(),
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
              ),
              const SizedBox(width: 4),
              const Icon(AppIcons.chevronRight, size: 16, color: AppColors.textSub),
            ],
          ),
        ),
      ),
    );
  }
}
