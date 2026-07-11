import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/countdown_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Streak-broken repair offer (screen_inventory §7b). Returns true if the user
/// chose to repair.
Future<bool?> showStreakRepairDialog(
  BuildContext context, {
  required int brokenValue,
  required int gemPrice,
  required Duration Function() remaining,
}) {
  return showAppDialog<bool>(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.flame, size: 44, color: AppColors.danger),
        const SizedBox(height: 14),
        Text(LocaleKeys.streakBrokenTitle.tr(), style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.streakBrokenBody.tr(namedArgs: {'days': '$brokenValue'}),
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${LocaleKeys.streakRepairEndsIn.tr()} ',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
            ),
            CountdownText(
              remaining: remaining,
              style: AppTextStyles.bodyStrong.copyWith(color: AppColors.danger),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: '${LocaleKeys.streakRepair.tr()}  ·  $gemPrice 💎',
          height: 52,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: LocaleKeys.streakRepairDecline.tr(),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    ),
  );
}

/// Freeze-consumed confirmation shown on launch when a freeze saved the streak
/// (decisions §8 / screen_inventory §7 OQ4).
Future<void> showFreezeConsumedDialog(BuildContext context) {
  return showAppDialog<void>(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.snowflake, size: 44, color: AppColors.gem),
        const SizedBox(height: 14),
        Text(LocaleKeys.streakConsumedTitle.tr(), style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.streakConsumedBody.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: LocaleKeys.commonContinue.tr(),
          height: 52,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
