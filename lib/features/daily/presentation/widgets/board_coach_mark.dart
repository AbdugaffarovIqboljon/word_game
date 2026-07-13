import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A coach-mark pill shown above the board on the first attempt (before any
/// guess is submitted): reminds the player how many attempts they have and that
/// the first letter is already given. Driven by daily state (not the board
/// cursor), so it renders immediately with the playing board — no delay.
class BoardCoachMark extends StatelessWidget {
  const BoardCoachMark({required this.attempts, super.key});

  final int attempts;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadii.pillR,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.info, size: 15, color: AppColors.gem),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                LocaleKeys.dailyAttemptsCoach.tr(
                  namedArgs: {'count': '$attempts'},
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
