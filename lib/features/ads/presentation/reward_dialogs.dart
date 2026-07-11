import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/primary_button.dart';

/// Rewarded-ad offer (screen_inventory §9a). The close (X) only becomes tappable
/// after a 2-second delay (anti-accidental-dismiss — implemented as real state).
/// Returns true if the user chose to watch.
Future<bool?> showRewardedAdOffer(
  BuildContext context, {
  required int coins,
}) {
  return showAppDialog<bool>(
    context,
    barrierDismissible: false,
    child: _RewardedAdOffer(coins: coins),
  );
}

/// Reward-granted confirmation (screen_inventory §9b).
Future<void> showRewardGranted(BuildContext context, {required int amount}) {
  return showAppDialog<void>(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoinBadge(),
        const SizedBox(height: 14),
        Text(
          LocaleKeys.dialogGrantedAmount.tr(namedArgs: {'count': '$amount'}),
          style: AppTextStyles.display.copyWith(color: AppColors.coin),
        ),
        const SizedBox(height: 4),
        Text(LocaleKeys.dialogGrantedTitle.tr(), style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.dialogGrantedBody.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: LocaleKeys.dialogGrantedCta.tr(),
          height: 52,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

class _RewardedAdOffer extends StatefulWidget {
  const _RewardedAdOffer({required this.coins});
  final int coins;

  @override
  State<_RewardedAdOffer> createState() => _RewardedAdOfferState();
}

class _RewardedAdOfferState extends State<_RewardedAdOffer> {
  bool _canClose = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _canClose = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: _canClose ? () => Navigator.of(context).pop(false) : null,
            icon: Icon(
              AppIcons.close,
              size: 20,
              color: _canClose ? AppColors.text3 : AppColors.muted,
            ),
          ),
        ),
        _CoinBadge(),
        const SizedBox(height: 14),
        Text(
          LocaleKeys.dialogRewardedTitle.tr(namedArgs: {'count': '${widget.coins}'}),
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.dialogRewardedBody.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: LocaleKeys.dialogRewardedCta.tr(),
          icon: AppIcons.watchAd,
          height: 52,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _CoinBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.coin,
        shape: BoxShape.circle,
        boxShadow: AppShadows.coinGlow,
      ),
      child: const Icon(AppIcons.coins, size: 36, color: AppColors.onGold),
    );
  }
}
