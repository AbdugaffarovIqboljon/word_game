/// Abstraction over in-app purchases / billing. Debug builds ship
/// `DebugPurchaseGateway`; release ships `StoreIapGateway` over
/// `in_app_purchase`. Fulfillment (crediting the wallet, setting remove-ads) is
/// owned by the gateway layer via `PurchaseFulfiller`, not the shop UI, because
/// real purchases resolve asynchronously and are re-delivered on restore.
abstract interface class PurchaseGateway {
  /// Initiates a purchase of [productId] and resolves `true` once it has been
  /// completed and fulfilled, `false` on cancel / error / store-unavailable.
  Future<bool> buy(String productId);

  /// Restores previously-owned non-consumable purchases (remove-ads). Resolves
  /// `true` if the restore flow ran (entitlements arrive via fulfillment).
  Future<bool> restore();
}
