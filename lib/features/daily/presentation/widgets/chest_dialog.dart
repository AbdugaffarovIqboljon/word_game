import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/game_config.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/countdown_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../ads/domain/reward_gateway.dart';
import '../../../ads/presentation/reward_dialogs.dart';
import '../../../wallet/data/wallet_service.dart';
import '../../data/daily_chest_repository.dart';

/// Daily chest (screen_inventory §9c): closed → opened, with a rewarded ×2
/// offer. Credits coins directly and marks the chest claimed. Returns when
/// dismissed so the caller can refresh the unclaimed dot.
///
/// WS2: claimable once per Tashkent day. If today's chest is already claimed the
/// dialog opens straight into the claimed "Ertaga qaytadan!" state (countdown to
/// the next chest) — no re-open, no second ×2 offer, no re-credit.
Future<void> showDailyChestDialog(
  BuildContext context, {
  required GameConfig config,
  required WalletService wallet,
  required RewardGateway rewardGateway,
  required DailyChestRepository chestRepo,
  required DateTime today,
  required Duration Function() remaining,
}) {
  return showAppDialog<void>(
    context,
    child: _ChestDialog(
      config: config,
      wallet: wallet,
      rewardGateway: rewardGateway,
      chestRepo: chestRepo,
      today: today,
      remaining: remaining,
    ),
  );
}

class _ChestDialog extends StatefulWidget {
  const _ChestDialog({
    required this.config,
    required this.wallet,
    required this.rewardGateway,
    required this.chestRepo,
    required this.today,
    required this.remaining,
  });

  final GameConfig config;
  final WalletService wallet;
  final RewardGateway rewardGateway;
  final DailyChestRepository chestRepo;
  final DateTime today;
  final Duration Function() remaining;

  @override
  State<_ChestDialog> createState() => _ChestDialogState();
}

class _ChestDialogState extends State<_ChestDialog> {
  /// Already claimed today when the dialog opened → straight to the locked state.
  late final bool _claimedBefore = widget.chestRepo.isClaimed(widget.today);
  bool _opened = false;
  bool _doubled = false;

  int get _reward => widget.config.dailyChestReward;

  Future<void> _open() async {
    // Guard: never credit twice for the same day, even on a double-tap.
    if (widget.chestRepo.isClaimed(widget.today)) return;
    await widget.wallet.creditCoins(_reward, reason: 'daily_chest');
    await widget.chestRepo.markClaimed(widget.today);
    if (mounted) setState(() => _opened = true);
  }

  Future<void> _double() async {
    final watch = await showRewardedAdOffer(context, coins: _reward);
    if (watch != true || !mounted) return;
    final earned =
        await widget.rewardGateway.showRewardedAd(RewardedPlacement.chestDouble);
    if (!earned || !mounted) return;
    // Credit the extra reward to make it ×2.
    await widget.wallet.creditCoins(_reward, reason: 'daily_chest_double');
    if (mounted) {
      setState(() => _doubled = true);
      await showRewardGranted(context, amount: _reward);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Claimed on a previous open today → locked "come back tomorrow" state.
    if (_claimedBefore && !_opened) return _claimedView();
    if (!_opened) return _closed();
    return _openedView();
  }

  Widget _claimedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.gift, size: 44, color: AppColors.muted),
        const SizedBox(height: 14),
        Text(
          LocaleKeys.dialogChestComeBack.tr(),
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 10),
        Text(
          LocaleKeys.dialogChestNextIn.tr(),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 4),
        CountdownText(
          remaining: widget.remaining,
          style: AppTextStyles.title.copyWith(color: AppColors.coin),
          // If the dialog is open across the rollover, close it so the fresh
          // chest can be claimed from the header.
          onElapsed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: LocaleKeys.commonClose.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _closed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.gift, size: 44, color: AppColors.coin),
        const SizedBox(height: 14),
        Text(LocaleKeys.dialogChestTitle.tr(), style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(LocaleKeys.dialogChestReady.tr(), style: AppTextStyles.body),
        const SizedBox(height: 20),
        PrimaryButton(
          label: LocaleKeys.dialogChestOpen.tr(),
          height: 52,
          onPressed: _open,
        ),
      ],
    );
  }

  Widget _openedView() {
    final amount = _doubled ? _reward * widget.config.dailyChestDoubleMultiplier : _reward;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.gift, size: 44, color: AppColors.successBright),
        const SizedBox(height: 14),
        Text(
          LocaleKeys.dialogChestReward.tr(namedArgs: {'count': '$amount'}),
          style: AppTextStyles.title.copyWith(color: AppColors.coin),
        ),
        const SizedBox(height: 4),
        Text(LocaleKeys.dialogChestOpened.tr(), style: AppTextStyles.body),
        const SizedBox(height: 20),
        // The ×2 offer hides itself when no rewarded ad is loaded (no fill).
        if (!_doubled)
          ValueListenableBuilder<bool>(
            valueListenable:
                widget.rewardGateway.isReady(RewardedPlacement.chestDouble),
            builder: (context, ready, _) {
              if (!ready) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label:
                        '${LocaleKeys.dialogChestDoubleCta.tr()}  ${LocaleKeys.dialogChestDoubleTitle.tr()}',
                    icon: AppIcons.watchAd,
                    height: 52,
                    onPressed: _double,
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: LocaleKeys.dialogChestClaimed.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
