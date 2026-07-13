import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A classic, dismissible coach mark shown above the board on the first attempt:
/// reminds the player how many attempts they have and that the first letter is
/// already given. Renders immediately (driven by daily state, not the board
/// cursor). Tapping it (or the OK chip) dismisses it — one-time, persisted.
class BoardCoachMark extends StatelessWidget {
  const BoardCoachMark({
    required this.attempts,
    required this.onDismiss,
    super.key,
  });

  final int attempts;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: AppColors.surface2,
          borderRadius: AppRadii.pillR,
          child: InkWell(
            onTap: onDismiss,
            borderRadius: AppRadii.pillR,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              decoration: BoxDecoration(
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
                      style: AppTextStyles.caption.copyWith(color: AppColors.text2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gem.withValues(alpha: 0.18),
                      borderRadius: AppRadii.chipR,
                    ),
                    child: Text(
                      LocaleKeys.commonOk.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gem,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
