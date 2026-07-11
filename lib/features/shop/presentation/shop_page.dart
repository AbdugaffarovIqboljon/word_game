import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/game/presentation/tile_skin.dart';
import '../../../core/game/presentation/tile_state.dart';
import '../../../core/game/presentation/widgets/static_tile.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../core/widgets/nav_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../wallet/data/wallet_service.dart';
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

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

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

  Future<void> _restore() async {
    await _iap.restore();
    if (mounted) _toast(LocaleKeys.shopRestore.tr());
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  HeroOfferCard(
                    price: _config.removeAdsBundleUsd,
                    owned: _purchases.removeAds.value,
                    onBuy: _buyRemoveAds,
                  ),
                  const SizedBox(height: 20),
                  for (final sku in _config.gemSkus) ...[
                    GemSkuTile(sku: sku, onBuy: () => _buyGems(sku)),
                    const SizedBox(height: 11),
                  ],
                  const SizedBox(height: 4),
                  SimpleIapCard(
                    icon: AppIcons.package,
                    title: LocaleKeys.shopHintPackTitle.tr(),
                    subtitle: LocaleKeys.shopHintPackSubtitle.tr(),
                    price: _config.hintPackUsd,
                    onBuy: _buyHintPack,
                  ),
                  const SizedBox(height: 20),
                  // One-time offer: hidden once owned (gated locally).
                  if (!_purchases.isOwned(SkuIds.starterPack))
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
                  const SizedBox(height: 24),
                  Text(LocaleKeys.shopSkinsTitle.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  for (final sku in _config.skins) ...[
                    SkinCard(
                      sku: sku,
                      owned: _skins.isOwned(sku.id),
                      active: _skins.isActive(sku.id),
                      onTap: () => _onSkin(sku),
                    ),
                    const SizedBox(height: 11),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _restore,
                      child: Text(
                        LocaleKeys.shopRestore.tr(),
                        style: AppTextStyles.body.copyWith(color: AppColors.gem),
                      ),
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.correct.withValues(alpha: 0.30),
            AppColors.telegram.withValues(alpha: 0.20),
          ],
        ),
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.correct.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.coin,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              LocaleKeys.shopBestOffer.tr(),
              style: AppTextStyles.micro.copyWith(color: AppColors.onGold),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(AppIcons.shieldCheck, size: 22, color: AppColors.successBright),
              const SizedBox(width: 10),
              Expanded(
                child: Text(LocaleKeys.shopHeroTitle.tr(), style: AppTextStyles.sectionTitle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.shopHeroSubtitle.tr(),
            style: AppTextStyles.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: owned ? LocaleKeys.shopSkinActive.tr() : _usd(price),
            onPressed: owned ? null : onBuy,
          ),
        ],
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
    return AppCard(
      borderColor: sku.bestValue ? AppColors.borderStrong : AppColors.border,
      child: Row(
        children: [
          const Icon(AppIcons.gem, size: 22, color: AppColors.gem),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${sku.total}', style: AppTextStyles.sectionTitle),
                    if (sku.bestValue) ...[
                      const SizedBox(width: 8),
                      _Badge(text: LocaleKeys.shopBestValue.tr()),
                    ],
                  ],
                ),
                if (sku.bonus > 0)
                  Text(
                    LocaleKeys.shopBonusGems.tr(namedArgs: {'count': '${sku.bonus}'}),
                    style: AppTextStyles.caption.copyWith(color: AppColors.successBright),
                  ),
              ],
            ),
          ),
          _PriceButton(label: _usd(sku.usd), onTap: onBuy),
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
          Icon(icon, size: 22, color: AppColors.coin),
          const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.danger.withValues(alpha: 0.25),
            AppColors.present.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.package, size: 22, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(LocaleKeys.shopStarterTitle.tr(), style: AppTextStyles.sectionTitle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.shopStarterSubtitle.tr(
              namedArgs: {'gems': '$gems', 'hints': '$hints'},
            ),
            style: AppTextStyles.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(AppIcons.clock, size: 14, color: AppColors.danger),
              const SizedBox(width: 6),
              Text('${LocaleKeys.shopStarterEndsIn.tr()} ', style: AppTextStyles.caption),
              CountdownText(
                remaining: remaining,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: '${_usd(wasPrice)}   ${_usd(price)}',
            onPressed: onBuy,
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SkinPreview(skin: TileSkin.byId(sku.id)),
          const SizedBox(width: 14),
          Expanded(child: Text(_nameKey.tr(), style: AppTextStyles.bodyStrong)),
          if (active)
            _Badge(text: LocaleKeys.shopSkinActive.tr())
          else if (owned)
            _PriceButton(label: LocaleKeys.shopSkinApply.tr(), onTap: onTap)
          else
            _PriceButton(label: '${sku.gemPrice} 💎', onTap: onTap),
        ],
      ),
    );
  }
}

/// Live 5-tile preview of a skin's correct-state color.
class SkinPreview extends StatelessWidget {
  const SkinPreview({required this.skin, super.key});

  final TileSkin skin;

  @override
  Widget build(BuildContext context) {
    return TileSkinScope(
      skin: skin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            const StaticTile(
              data: TileData(letter: 'a', state: TileState.correct),
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.correct.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.micro.copyWith(color: AppColors.successBright),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

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
