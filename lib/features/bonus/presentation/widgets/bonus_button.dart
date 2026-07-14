import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/primary_button.dart';

/// The "Yana yechish" action on the daily result (WS3).
///
/// * Pro (remove-ads) users get an enabled primary button that starts a bonus
///   word ([onPlay]).
/// * Free users get a prominent gold `premium` CTA advertising the Pro
///   unlock; tapping it opens the shop's remove-ads hero as a natural upsell
///   ([onUpsell]).
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
    return PrimaryButton(
      label: LocaleKeys.bonusProCta.tr(),
      icon: AppIcons.sparkles,
      variant: PrimaryButtonVariant.premium,
      onPressed: onUpsell,
    );
  }
}
