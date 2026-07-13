import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';

/// The "Yana yechish" action on the daily result (WS3).
///
/// * Pro (remove-ads) users get an enabled primary button that starts a bonus
///   word ([onPlay]).
/// * Free users get a locked-styled button with a padlock; tapping it opens the
///   shop's remove-ads hero as a natural upsell ([onUpsell]).
class BonusButton extends StatelessWidget {
  const BonusButton({
    required this.isPro,
    required this.onPlay,
    required this.onUpsell,
    super.key,
  });

  final bool isPro;
  final VoidCallback onPlay;
  final VoidCallback onUpsell;

  @override
  Widget build(BuildContext context) {
    if (isPro) {
      return PrimaryButton(
        label: LocaleKeys.bonusAgain.tr(),
        icon: AppIcons.refresh,
        onPressed: onPlay,
      );
    }
    return Material(
      color: AppColors.disabledBg,
      borderRadius: AppRadii.buttonR,
      child: InkWell(
        onTap: onUpsell,
        borderRadius: AppRadii.buttonR,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.buttonR,
            border: Border.all(color: AppColors.disabledBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.lock, size: 16, color: AppColors.disabledFg),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.bonusAgain.tr(),
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 16,
                  color: AppColors.disabledFg,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.bonusProHint.tr(),
                style: AppTextStyles.caption.copyWith(color: AppColors.gem),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
