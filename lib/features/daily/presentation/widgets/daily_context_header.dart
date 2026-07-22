import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/l10n/uzbek_date.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact context block between the app bar and the board: puzzle number,
/// localized date, and the "find today's word" subtitle. The rules (?) and hint
/// (💡) actions now live in the top app bar (WS3), so this block is content-only
/// plus the skin-accent chip around the puzzle number.
class DailyContextHeader extends StatelessWidget {
  const DailyContextHeader({
    required this.puzzleNumber,
    required this.date,
    this.accent,
    super.key,
  });

  final int puzzleNumber;
  final DateTime date;

  /// Active skin accent (WS4): tints the puzzle-number chip. Null / the neutral
  /// default leaves the header on the base palette (Standart).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final isNeutral = accent == null || accent == AppColors.textSub;
    final label = Text(
      LocaleKeys.dailyPuzzleNumber.tr(namedArgs: {'n': '$puzzleNumber'}),
      style: AppTextStyles.navTitle.copyWith(
        color: isNeutral ? null : accent,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Skin-accent chip around the puzzle number (WS4); Standart renders
            // the bare label with no chip fill.
            Flexible(
              child: isNeutral
                  ? label
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent!.withValues(alpha: 0.14),
                        borderRadius: AppRadii.chipR,
                        border: Border.all(
                          color: accent!.withValues(alpha: 0.35),
                        ),
                      ),
                      child: label,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          UzbekDate.format(date),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 2),
        Text(LocaleKeys.dailySubtitle.tr(), style: AppTextStyles.caption),
      ],
    );
  }
}
