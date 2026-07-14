import '../../wallet/data/wallet_service.dart';
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

  /// Debug-only QA aid: tile skins are gem-priced, not real-money SKUs, so they
  /// never flow through [buy] — this tops up the wallet directly so every skin
  /// in the catalog can be bought and equipped from the shop without grinding
  /// for gems. Never called in release (gated by [Env.useFakeIap] at the call
  /// site, same flag that selects this gateway).
  Future<void> debugGrantGems(WalletService wallet, int amount) =>
      wallet.creditGems(amount, reason: 'debug_grant');
}
