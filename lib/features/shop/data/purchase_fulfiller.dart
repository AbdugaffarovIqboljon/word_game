import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/game_config.dart';
import '../../wallet/data/wallet_service.dart';
import '../domain/sku_ids.dart';
import 'purchases_repository.dart';

/// The single place a completed purchase is turned into entitlements.
///
/// Fulfillment MUST live here (not in the shop UI) because real purchases arrive
/// asynchronously — a pending purchase resolves later, and the non-consumable is
/// re-delivered on restore/next launch. Both [DebugPurchaseGateway] and the real
/// store gateway call [fulfill] so debug and release credit identically and the
/// wallet is credited atomically with marking ownership.
class PurchaseFulfiller {
  const PurchaseFulfiller({
    required WalletService wallet,
    required PurchasesRepository purchases,
    required GameConfig config,
    required AnalyticsService analytics,
  })  : _wallet = wallet,
        _purchases = purchases,
        _config = config,
        _analytics = analytics;

  final WalletService _wallet;
  final PurchasesRepository _purchases;
  final GameConfig _config;
  final AnalyticsService _analytics;

  /// Applies the grant for [sku] and fires `iap_purchase`. Idempotent for the
  /// entitlements it owns: the non-consumable and the one-time starter pack are
  /// no-ops if already owned, so a duplicate stream delivery can't double-grant.
  Future<void> fulfill(String sku) async {
    switch (sku) {
      case SkuIds.removeAds:
        await _purchases.setRemoveAds(true);
        await _purchases.markOwned(SkuIds.removeAds);
      case SkuIds.starterPack:
        if (_purchases.isOwned(SkuIds.starterPack)) return; // one-time gate
        await _wallet.creditGems(_config.starterPackGems, reason: 'iap_starter');
        await _wallet.creditCoins(
          _config.starterPackHints * _config.hintDictionaryPrice,
          reason: 'iap_starter_hints',
        );
        await _purchases.markOwned(SkuIds.starterPack);
      case SkuIds.hintPack:
        // v1: no separate hint-token inventory — grant an equivalent coin bundle.
        await _wallet.creditCoins(
          _config.hintPackCount * _config.hintDictionaryPrice,
          reason: 'iap_hint_pack',
        );
      default:
        final gem = _config.gemSkus.where((g) => g.sku == sku);
        if (gem.isEmpty) return; // unknown sku — nothing to grant
        await _wallet.creditGems(gem.first.total, reason: 'iap_gems');
    }
    _analytics.iapPurchase(sku: sku);
  }

  /// The starter pack is a one-time local purchase; the shop uses this to gate.
  bool get starterOwned => _purchases.isOwned(SkuIds.starterPack);
}
