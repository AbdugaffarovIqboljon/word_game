import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/game/presentation/tile_skin.dart';
import '../../../core/game/presentation/tile_state.dart';
import '../../../core/game/presentation/tile_visuals.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../core/widgets/nav_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/debug_purchase_gateway.dart';
import '../data/purchases_repository.dart';
import '../data/skin_service.dart';
import '../domain/purchase_gateway.dart';
import '../domain/sku_ids.dart';

/// Shop — one scrollable route (decisions §8): remove-ads hero, gems ladder,
/// hint bundle, time-limited starter pack, and the tile-skin gallery with a live
/// preview + apply.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final GameConfig _config = sl<GameConfig>();
  final WalletService _wallet = sl<WalletService>();
  final PurchaseGateway _iap = sl<PurchaseGateway>();
  final PurchasesRepository _purchases = sl<PurchasesRepository>();
  final SkinService _skins = sl<SkinService>();

  // Purchases only INITIATE here — the gateway fulfills (credits wallet / sets
  // remove-ads) centrally on the store's purchase stream, so a pending purchase
  // that approves later still lands. Balances update reactively via the wallet
  // notifiers; setState refreshes the entitlement-gated cards.
  Future<void> _buyRemoveAds() async {
    await _iap.buy(SkuIds.removeAds);
    if (mounted) setState(() {});
  }

  Future<void> _buyGems(GemSku sku) => _iap.buy(sku.sku);

  Future<void> _buyHintPack() => _iap.buy(SkuIds.hintPack);

  Future<void> _buyStarter() async {
    await _iap.buy(SkuIds.starterPack);
    if (mounted) setState(() {});
  }

  Future<void> _onSkin(SkinSku sku) async {
    if (_skins.isOwned(sku.id)) {
      await _skins.select(sku.id);
    } else if (await _wallet.debitGems(sku.gemPrice, reason: 'skin_${sku.id}')) {
      await _skins.own(sku.id);
      await _skins.select(sku.id);
    } else {
      return;
    }
    if (mounted) setState(() {});
  }

  // Debug-only QA aid: tile skins are gem-priced, not real-money SKUs, so the
  // shop's normal buy flow can't be exercised through a fake IAP purchase. This
  // tops up gems directly so every skin can be bought and equipped without
  // grinding. Gated on the same flag that selects the debug gateway, so it's
  // unreachable in a release build.
  Future<void> _debugGrantGems() async {
    final iap = _iap;
    if (iap is DebugPurchaseGateway) {
      await iap.debugGrantGems(_wallet, 1000);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavHeader(
              title: LocaleKeys.shopNavTitle.tr(),
              trailing: GemChip(balance: _wallet.gems),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s5,
                  AppSpacing.s2,
                  AppSpacing.s5,
                  AppSpacing.s6,
                ),
                children: [
                  HeroOfferCard(
                    price: _config.removeAdsBundleUsd,
                    owned: _purchases.removeAds.value,
                    onBuy: _buyRemoveAds,
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  // One-time offer: hidden once owned (gated locally). Promoted
                  // to right after the hero card — it carries urgency (the
                  // countdown) and converts best right after the top offer.
                  if (!_purchases.isOwned(SkuIds.starterPack)) ...[
                    StarterPackBanner(
                      price: _config.starterPackUsd,
                      wasPrice: _config.starterPackWasUsd,
                      gems: _config.starterPackGems,
                      hints: _config.starterPackHints,
                      remaining: () => _purchases
                          .starterDeadline(
                            Duration(hours: _config.starterPackWindowHours),
                          )
                          .difference(DateTime.now()),
                      onBuy: _buyStarter,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                  ],
                  Text(LocaleKeys.shopGemsTitle.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.s3),
                  // 2-column ladder (reference design 6a): pair up tiles, the
                  // odd tile left of an empty cell if the ladder length is odd.
                  for (var i = 0; i < _config.gemSkus.length; i += 2) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.gap11),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GemSkuTile(
                            sku: _config.gemSkus[i],
                            onBuy: () => _buyGems(_config.gemSkus[i]),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gap11),
                        Expanded(
                          child: i + 1 < _config.gemSkus.length
                              ? GemSkuTile(
                                  sku: _config.gemSkus[i + 1],
                                  onBuy: () => _buyGems(_config.gemSkus[i + 1]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    LocaleKeys.shopHelpSectionTitle.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  SimpleIapCard(
                    icon: AppIcons.hint,
                    title: LocaleKeys.shopHintPackTitle.tr(),
                    subtitle: LocaleKeys.shopHintPackSubtitle.tr(),
                    price: _config.hintPackUsd,
                    onBuy: _buyHintPack,
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(LocaleKeys.shopSkinsTitle.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.s3),
                  for (var i = 0; i < _config.skins.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.gap11),
                    SkinCard(
                      sku: _config.skins[i],
                      owned: _skins.isOwned(_config.skins[i].id),
                      active: _skins.isActive(_config.skins[i].id),
                      onTap: () => _onSkin(_config.skins[i]),
                    ),
                  ],
                  if (Env.useFakeIap) ...[
                    const SizedBox(height: AppSpacing.s3),
                    Center(
                      child: TextButton(
                        onPressed: _debugGrantGems,
                        child: const Text('DEBUG: +1000 💎 (skin QA)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _usd(double v) => '\$${v.toStringAsFixed(2)}';

class HeroOfferCard extends StatelessWidget {
  const HeroOfferCard({
    required this.price,
    required this.owned,
    required this.onBuy,
    super.key,
  });

  final double price;
  final bool owned;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.cardR,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
          ),
          borderRadius: AppRadii.cardR,
          border: Border.all(color: AppColors.correct),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -14,
              child: Icon(
                AppIcons.shieldCheck,
                size: 96,
                color: AppColors.successBright.withValues(alpha: 0.18),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.correct,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    LocaleKeys.shopBestOffer.tr(),
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.white,
                      letterSpacing: 0.1 * 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  LocaleKeys.shopHeroTitle.tr(),
                  style: AppTextStyles.sectionTitle.copyWith(height: 1.25),
                ),
                const SizedBox(height: 14),
                if (owned)
                  Row(
                    children: [
                      const Icon(AppIcons.check, size: 16, color: AppColors.successBright),
                      const SizedBox(width: 6),
                      Text(
                        LocaleKeys.shopSkinActive.tr(),
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.successBright,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _usd(price),
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 22,
                          color: AppColors.successBright,
                        ),
                      ),
                      PrimaryButton(
                        label: LocaleKeys.shopHeroBuy.tr(),
                        onPressed: onBuy,
                        height: 40,
                        horizontalPadding: 20,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GemSkuTile extends StatelessWidget {
  const GemSkuTile({required this.sku, required this.onBuy, super.key});

  final GemSku sku;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    // The bonus-line slot is reserved (fixed height) whether or not it has
    // text, so every tile in the 2-column ladder lines up. Real bonus copy
    // wins; a best-value tile with no bonus falls back to that label instead.
    final bonusText = sku.bonus > 0
        ? LocaleKeys.shopBonusGems.tr(namedArgs: {'count': '${sku.bonus}'})
        : (sku.bestValue ? LocaleKeys.shopBestValue.tr() : null);

    return AppCard(
      borderColor: sku.bestValue ? AppColors.borderStrong : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.gem, size: 18, color: AppColors.gem),
              const SizedBox(width: AppSpacing.gap6),
              Text(
                '${sku.total}',
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 18),
              ),
            ],
          ),
          SizedBox(
            height: 15,
            child: bonusText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      bonusText,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.successBright,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          _PriceButton(label: _usd(sku.usd), onTap: onBuy, fullWidth: true),
        ],
      ),
    );
  }
}

class SimpleIapCard extends StatelessWidget {
  const SimpleIapCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onBuy,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fire.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 22, color: AppColors.fire),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          _PriceButton(label: _usd(price), onTap: onBuy),
        ],
      ),
    );
  }
}

class StarterPackBanner extends StatelessWidget {
  const StarterPackBanner({
    required this.price,
    required this.wasPrice,
    required this.gems,
    required this.hints,
    required this.remaining,
    required this.onBuy,
    super.key,
  });

  final double price;
  final double wasPrice;
  final int gems;
  final int hints;
  final Duration Function() remaining;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.starterGradientStart, AppColors.starterGradientEnd],
        ),
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(AppIcons.package, size: 24, color: AppColors.dangerLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LocaleKeys.shopStarterTitle.tr(), style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        LocaleKeys.shopStarterSubtitle.tr(
                          namedArgs: {'gems': '$gems', 'hints': '$hints'},
                        ),
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: AppColors.dangerSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    CountdownText(
                      remaining: remaining,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 11.5,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _usd(wasPrice),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSub,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textSub,
                ),
              ),
              const SizedBox(height: 3),
              PrimaryButton(
                label: _usd(price),
                onPressed: onBuy,
                variant: PrimaryButtonVariant.danger,
                height: 36,
                horizontalPadding: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkinCard extends StatelessWidget {
  const SkinCard({
    required this.sku,
    required this.owned,
    required this.active,
    required this.onTap,
    super.key,
  });

  final SkinSku sku;
  final bool owned;
  final bool active;
  final VoidCallback onTap;

  String get _nameKey => switch (sku.id) {
    'milliy' => LocaleKeys.shopSkinMilliy,
    'neon' => LocaleKeys.shopSkinNeon,
    'oltin' => LocaleKeys.shopSkinOltin,
    _ => LocaleKeys.shopSkinStandart,
  };

  String get _tag => switch ((active, owned)) {
    (true, _) => LocaleKeys.shopSkinActive.tr(),
    (false, true) => LocaleKeys.shopSkinApply.tr(),
    (false, false) => '${sku.gemPrice} 💎',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkinPreviewRow(skin: TileSkin.byId(sku.id)),
          const SizedBox(height: AppSpacing.gap11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(_nameKey.tr(), style: AppTextStyles.bodyStrong.copyWith(fontSize: 14))),
              Text(
                _tag,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 12, color: AppColors.gem),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live 5-tile preview of a skin's correct-state color, spelling "QALAM" (a
/// real Uzbek word — pen) to match the board's tile width.
class SkinPreviewRow extends StatelessWidget {
  const SkinPreviewRow({required this.skin, super.key});

  final TileSkin skin;

  static const _letters = ['Q', 'A', 'L', 'A', 'M'];

  @override
  Widget build(BuildContext context) {
    final visuals = tileVisualsFor(TileState.correct, skin: skin);
    return Row(
      children: [
        for (var i = 0; i < _letters.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.gap5),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: visuals.background,
                  borderRadius: AppRadii.tileR,
                ),
                child: Center(
                  child: Text(_letters[i], style: AppTextStyles.tile(15, color: visuals.foreground)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.label, required this.onTap, this.fullWidth = false});
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: AppRadii.chipR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.chipR,
        child: Container(
          height: 36,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.chipR,
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Text(label, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}
