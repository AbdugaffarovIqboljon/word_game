/// Abstraction over in-app purchases / billing. The real StoreKit/Play Billing
/// integration is a later work package; v1 ships [DebugPurchaseGateway].
abstract interface class PurchaseGateway {
  /// Buys a product by id. Resolves `true` on a completed purchase.
  Future<bool> buy(String productId);

  /// Restores previously-owned non-consumable purchases.
  Future<bool> restore();
}

/// Debug fake: every purchase and restore succeeds instantly.
class DebugPurchaseGateway implements PurchaseGateway {
  const DebugPurchaseGateway();

  @override
  Future<bool> buy(String productId) async => true;

  @override
  Future<bool> restore() async => true;
}
