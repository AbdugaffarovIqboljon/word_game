/// Store product ids the owner must create (Phase D). Gem SKUs live on
/// [GameConfig.gemSkus] since they carry catalog data; the rest are fixed here.
///
/// Consumable vs non-consumable matters for how `in_app_purchase` buys and for
/// restore (only the non-consumable [removeAds] is restorable).
abstract final class SkuIds {
  const SkuIds._();

  /// Non-consumable: kills interstitials forever + grants the daily free hint.
  static const String removeAds = 'soz_jangi_remove_ads';

  /// Consumable, one-time gated locally: gems + hint bundle at a discount.
  static const String starterPack = 'starter_pack_1';

  /// Consumable hint bundle (kept beyond the 5 named SKUs by product decision).
  static const String hintPack = 'soz_jangi_hint_pack';

  static const List<String> gems = [
    'gems_small_100',
    'gems_med_350',
    'gems_large_1100',
  ];

  /// Non-consumables (restorable).
  static const Set<String> nonConsumables = {removeAds};

  /// Everything the store must be queried for.
  static Set<String> get all => {removeAds, starterPack, hintPack, ...gems};

  static bool isConsumable(String sku) => !nonConsumables.contains(sku);
}
