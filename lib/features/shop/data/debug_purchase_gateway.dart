import '../domain/purchase_gateway.dart';
import 'purchase_fulfiller.dart';

/// Debug fake used when [Env.useFakeIap] is on (all debug builds, all tests):
/// every purchase "succeeds" instantly and is fulfilled through the same
/// [PurchaseFulfiller] the real gateway uses, so the debug shop credits exactly
/// like release without ever touching the store.
class DebugPurchaseGateway implements PurchaseGateway {
  const DebugPurchaseGateway(this._fulfiller);

  final PurchaseFulfiller _fulfiller;

  @override
  Future<bool> buy(String productId) async {
    await _fulfiller.fulfill(productId);
    return true;
  }

  @override
  Future<bool> restore() async => true;
}
