import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/l10n/locale_keys.dart';
import '../domain/hint_type.dart';

/// Pay for a hint. [viaAd] true → rewarded ad, else coins. Returns whether the
/// purchase (and effect) succeeded.
typedef HintPurchase = Future<bool> Function(HintType type, {required bool viaAd});

/// Opens the hint bottom sheet over a dimmed/blurred backdrop.
Future<void> showHintSheet(
  BuildContext context, {
  required ValueListenable<int> coinBalance,
  required int revealPrice,
  required int cleanPrice,
  required int dictionaryPrice,
  required String? definition,
  required HintPurchase onBuy,
  bool revealAdAvailable = true,
  bool cleanAdAvailable = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: AppColors.scrim,
    builder: (_) => HintSheet(
      coinBalance: coinBalance,
      revealPrice: revealPrice,
      cleanPrice: cleanPrice,
      dictionaryPrice: dictionaryPrice,
      definition: definition,
      onBuy: onBuy,
      revealAdAvailable: revealAdAvailable,
      cleanAdAvailable: cleanAdAvailable,
    ),
  );
}

/// Hint sheet (screen_inventory §4). Two states driven purely by the live coin
/// balance: default (all affordable) and insufficient (coin buttons disabled,
/// ad buttons emphasized, Lugʻat card locked).
class HintSheet extends StatefulWidget {
  const HintSheet({
    required this.coinBalance,
    required this.revealPrice,
    required this.cleanPrice,
    required this.dictionaryPrice,
    required this.definition,
    required this.onBuy,
    this.revealAdAvailable = true,
    this.cleanAdAvailable = true,
    super.key,
  });

  final ValueListenable<int> coinBalance;
  final int revealPrice;
  final int cleanPrice;
  final int dictionaryPrice;
  final String? definition;
  final HintPurchase onBuy;
  // Rewarded-ad readiness per placement; the "watch ad" button hides on no-fill.
  final bool revealAdAvailable;
  final bool cleanAdAvailable;

  @override
  State<HintSheet> createState() => _HintSheetState();
}

class _HintSheetState extends State<HintSheet> {
  bool _definitionRevealed = false;

  Future<void> _buy(HintType type, {required bool viaAd}) async {
    final ok = await widget.onBuy(type, viaAd: viaAd);
    if (!ok || !mounted) return;
    if (type == HintType.dictionary) {
      setState(() => _definitionRevealed = true);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadii.sheetTopR,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sheetUp,
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<int>(
          valueListenable: widget.coinBalance,
          builder: (context, coins, _) {
            final insufficient = coins < widget.dictionaryPrice;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(LocaleKeys.hintTitle.tr(), style: AppTextStyles.sectionTitle),
                      _CoinBadge(coins: coins, danger: insufficient),
                    ],
                  ),
                  if (insufficient) ...[
                    const SizedBox(height: 6),
                    Text(
                      LocaleKeys.hintInsufficient.tr(),
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 16),
                  HintActionCard(
                    icon: AppIcons.reveal,
                    iconColor: AppColors.fire,
                    name: LocaleKeys.hintRevealName.tr(),
                    description: LocaleKeys.hintRevealDesc.tr(),
                    price: widget.revealPrice,
                    canAffordCoins: coins >= widget.revealPrice,
                    emphasizeAd: insufficient,
                    onCoin: () => _buy(HintType.revealLetter, viaAd: false),
                    onAd: widget.revealAdAvailable
                        ? () => _buy(HintType.revealLetter, viaAd: true)
                        : null,
                  ),
                  const SizedBox(height: 11),
                  HintActionCard(
                    icon: AppIcons.clean,
                    iconColor: AppColors.gem,
                    name: LocaleKeys.hintCleanName.tr(),
                    description: LocaleKeys.hintCleanDesc.tr(),
                    price: widget.cleanPrice,
                    canAffordCoins: coins >= widget.cleanPrice,
                    emphasizeAd: insufficient,
                    onCoin: () => _buy(HintType.cleanKeyboard, viaAd: false),
                    onAd: widget.cleanAdAvailable
                        ? () => _buy(HintType.cleanKeyboard, viaAd: true)
                        : null,
                  ),
                  const SizedBox(height: 11),
                  HintActionCard(
                    icon: AppIcons.dictionary,
                    iconColor: AppColors.successBright,
                    name: LocaleKeys.hintDictionaryName.tr(),
                    description: _definitionRevealed && widget.definition != null
                        ? widget.definition!
                        : LocaleKeys.hintDictionaryDesc.tr(),
                    price: widget.dictionaryPrice,
                    canAffordCoins: coins >= widget.dictionaryPrice,
                    // Dictionary has no ad fallback → whole card locks if unaffordable.
                    locked: coins < widget.dictionaryPrice && !_definitionRevealed,
                    onCoin: _definitionRevealed
                        ? null
                        : () => _buy(HintType.dictionary, viaAd: false),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins, required this.danger});

  final int coins;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.pillR,
        border: Border.all(color: danger ? AppColors.danger : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: AppTextStyles.bodyStrong.copyWith(
              color: danger ? AppColors.danger : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// One hint card: icon avatar, name/description, and a coin button plus an
/// optional watch-ad button.
class HintActionCard extends StatelessWidget {
  const HintActionCard({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.description,
    required this.price,
    required this.canAffordCoins,
    required this.onCoin,
    this.onAd,
    this.emphasizeAd = false,
    this.locked = false,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String description;
  final int price;
  final bool canAffordCoins;
  final VoidCallback? onCoin;
  final VoidCallback? onAd;
  final bool emphasizeAd;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardR,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: locked
                  ? const Icon(AppIcons.lock, size: 18, color: AppColors.muted)
                  : Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!locked) ...[
              const SizedBox(width: 10),
              _Buttons(
                price: price,
                canAffordCoins: canAffordCoins,
                onCoin: onCoin,
                onAd: onAd,
                emphasizeAd: emphasizeAd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.price,
    required this.canAffordCoins,
    required this.onCoin,
    required this.onAd,
    required this.emphasizeAd,
  });

  final int price;
  final bool canAffordCoins;
  final VoidCallback? onCoin;
  final VoidCallback? onAd;
  final bool emphasizeAd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoinPriceButton(
          price: price,
          enabled: canAffordCoins && onCoin != null,
          onTap: onCoin,
        ),
        if (onAd != null) ...[
          const SizedBox(height: 6),
          _AdButton(emphasized: emphasizeAd, onTap: onAd!),
        ],
      ],
    );
  }
}

class _CoinPriceButton extends StatelessWidget {
  const _CoinPriceButton({
    required this.price,
    required this.enabled,
    required this.onTap,
  });

  final int price;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.text : AppColors.disabledFg;
    return _PillButton(
      onTap: enabled ? onTap : null,
      background: enabled ? AppColors.surface2 : AppColors.disabledBg,
      border: enabled ? AppColors.border : AppColors.disabledBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.coins, size: 14, color: enabled ? AppColors.coin : fg),
          const SizedBox(width: 5),
          Text('$price', style: AppTextStyles.bodyStrong.copyWith(fontSize: 13, color: fg)),
        ],
      ),
    );
  }
}

class _AdButton extends StatelessWidget {
  const _AdButton({required this.emphasized, required this.onTap});

  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      onTap: onTap,
      background: emphasized ? AppColors.correct : AppColors.surface2,
      border: emphasized ? AppColors.correct : AppColors.border,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.watchAd,
            size: 14,
            color: emphasized ? AppColors.white : AppColors.text2,
          ),
          const SizedBox(width: 5),
          Text(
            LocaleKeys.hintWatchAd.tr(),
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: emphasized ? AppColors.white : AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.child,
    required this.onTap,
    required this.background,
    required this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: AppRadii.chipR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.chipR,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.chipR,
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}
