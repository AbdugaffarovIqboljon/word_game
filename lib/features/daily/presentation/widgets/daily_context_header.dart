import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/l10n/uzbek_date.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_icon_button.dart';

/// Compact context block between the app bar and the board: puzzle number,
/// localized date, and the "find today's word" subtitle. Hosts the re-openable
/// rules (circle-help) button and — freed from the crowded app bar — the hint
/// (lightbulb) action while a puzzle is in progress.
class DailyContextHeader extends StatelessWidget {
  const DailyContextHeader({
    required this.puzzleNumber,
    required this.date,
    required this.onRules,
    this.onHint,
    super.key,
  });

  final int puzzleNumber;
  final DateTime date;
  final VoidCallback onRules;

  /// Present only while a puzzle is playable.
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                LocaleKeys.dailyPuzzleNumber.tr(
                  namedArgs: {'n': '$puzzleNumber'},
                ),
                style: AppTextStyles.navTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppIconButton(
              icon: AppIcons.help,
              onPressed: onRules,
              tooltip: LocaleKeys.commonRules.tr(),
            ),
            if (onHint != null) ...[
              const SizedBox(width: 6),
              AppIconButton(
                icon: AppIcons.hint,
                iconColor: AppColors.fire,
                onPressed: onHint!,
              ),
            ],
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
