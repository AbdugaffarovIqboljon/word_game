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

/// Reward-granted confirmation (screen_inventory §9b, reworked for WS6).
///
/// The reward is already credited by the caller; this dialog only celebrates it:
/// a coin badge + count-up to [amount], then it auto-dismisses after
/// [autoCloseMs] (RC `reward_dialog_auto_close_ms`, default 1600). There is no
/// "Oldim" button — tapping anywhere dismisses early, and the dialog never
/// blocks input longer than its own animation.
Future<void> showRewardGranted(
  BuildContext context, {
  required int amount,
  int autoCloseMs = 1600,
}) {
  return showAppDialog<void>(
    context,
    child: _RewardGrantedDialog(amount: amount, autoCloseMs: autoCloseMs),
  );
}

class _RewardGrantedDialog extends StatefulWidget {
  const _RewardGrantedDialog({required this.amount, required this.autoCloseMs});

  final int amount;
  final int autoCloseMs;

  @override
  State<_RewardGrantedDialog> createState() => _RewardGrantedDialogState();
}

class _RewardGrantedDialogState extends State<_RewardGrantedDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.autoCloseMs), _dismiss);
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The count-up runs over the first ~60% of the visible window so the final
    // number settles well before auto-dismiss.
    final countMs = (widget.autoCloseMs * 0.6).clamp(200, 900).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CoinBadge(),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: widget.amount.toDouble()),
            duration: Duration(milliseconds: countMs),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              LocaleKeys.dialogGrantedAmount
                  .tr(namedArgs: {'count': '${value.round()}'}),
              style: AppTextStyles.display.copyWith(color: AppColors.coin),
            ),
          ),
          const SizedBox(height: 4),
          Text(LocaleKeys.dialogGrantedTitle.tr(), style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.dialogGrantedBody.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
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
