import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/purchase_gateway.dart';
import '../domain/sku_ids.dart';
import 'purchase_fulfiller.dart';

/// Production [PurchaseGateway] over `in_app_purchase` (StoreKit / Play Billing).
///
/// Fulfillment is centralised on the purchase stream: a purchase may arrive long
/// after [buy] returns (pending → approved) or on the next launch (restore), so
/// entitlements are granted from [_onPurchases], not from the shop UI. [buy]
/// bridges the async stream back to a `Future<bool>` via a per-product completer.
///
/// Validation is client-side only for v1 (documented): [_verified] trusts the
/// store's own signed receipt. Server-side receipt validation is a later work
/// package.
class StoreIapGateway implements PurchaseGateway {
  StoreIapGateway({
    required InAppPurchase iap,
    required PurchaseFulfiller fulfiller,
  })  : _iap = iap,
        _fulfiller = fulfiller;

  final InAppPurchase _iap;
  final PurchaseFulfiller _fulfiller;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = {};
  final Map<String, Completer<bool>> _pending = {};
  bool _available = false;

  /// Whether billing is reachable; the shop shows a retry state when false.
  bool get isAvailable => _available;

  static Future<StoreIapGateway> create({
    required PurchaseFulfiller fulfiller,
    InAppPurchase? iap,
  }) async {
    final gateway = StoreIapGateway(
      iap: iap ?? InAppPurchase.instance,
      fulfiller: fulfiller,
    );
    await gateway._init();
    return gateway;
  }

  Future<void> _init() async {
    try {
      _available = await _iap.isAvailable();
      // Subscribe first so pending / restored transactions delivered on launch
      // are handled and completed.
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (_) {},
      );
      if (_available) await _loadProducts();
    } catch (e) {
      if (kDebugMode) debugPrint('IAP init failed — store disabled: $e');
      _available = false;
    }
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(SkuIds.all);
    for (final pd in response.productDetails) {
      _products[pd.id] = pd;
    }
  }

  @override
  Future<bool> buy(String productId) async {
    if (!_available) return false;
    final product = _products[productId] ?? await _fetchProduct(productId);
    if (product == null) return false;

    // Replace any stale completer for this product (previous attempt abandoned).
    _pending.remove(productId)?.complete(false);
    final completer = Completer<bool>();
    _pending[productId] = completer;

    final param = PurchaseParam(productDetails: product);
    try {
      if (SkuIds.isConsumable(productId)) {
        await _iap.buyConsumable(purchaseParam: param);
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      _pending.remove(productId);
      if (kDebugMode) debugPrint('buy($productId) failed: $e');
      return false;
    }
    return completer.future;
  }

  @override
  Future<bool> restore() async {
    if (!_available) return false;
    try {
      await _iap.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ProductDetails?> _fetchProduct(String id) async {
    try {
      final response = await _iap.queryProductDetails({id});
      for (final pd in response.productDetails) {
        _products[pd.id] = pd;
      }
    } catch (_) {}
    return _products[id];
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break; // await a terminal update; buy()'s future stays open
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_verified(purchase)) {
            await _fulfiller.fulfill(purchase.productID);
            _resolve(purchase.productID, true);
          } else {
            _resolve(purchase.productID, false);
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _resolve(purchase.productID, false);
      }
      // Always acknowledge, or the store re-delivers the transaction forever.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Client-side validation only for v1: trust the store's signed transaction.
  bool _verified(PurchaseDetails purchase) => true;

  void _resolve(String productId, bool success) {
    final completer = _pending.remove(productId);
    if (completer != null && !completer.isCompleted) completer.complete(success);
  }

  void dispose() => _sub?.cancel();
}
