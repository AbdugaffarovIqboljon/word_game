import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/preferences_service.dart';
import '../domain/wallet_analytics.dart';
import '../domain/wallet_transaction.dart';

/// The single source of truth for the player's coin & gem balances.
///
/// Balances are exposed as [ValueListenable]s so header chips update reactively
/// without rebuilding whole screens. Debits are atomic — [debitCoins]/[debitGems]
/// return `false` and change nothing if funds are insufficient. Every mutation
/// appends a [WalletTransaction] to the ledger and fires the [WalletAnalytics]
/// hook.
class WalletService {
  WalletService({
    required PreferencesService prefs,
    WalletAnalytics analytics = const NoopWalletAnalytics(),
  }) : _prefs = prefs,
       _analytics = analytics;

  static const _coinsKey = 'wallet_coins';
  static const _gemsKey = 'wallet_gems';
  static const _ledgerKey = 'wallet_ledger';
  static const _ledgerCap = 200; // keep the most recent N entries

  final PreferencesService _prefs;
  final WalletAnalytics _analytics;

  final ValueNotifier<int> _coins = ValueNotifier(0);
  final ValueNotifier<int> _gems = ValueNotifier(0);

  ValueListenable<int> get coins => _coins;
  ValueListenable<int> get gems => _gems;

  int get coinBalance => _coins.value;
  int get gemBalance => _gems.value;

  /// Loads persisted balances. Call once at startup.
  void load() {
    _coins.value = _prefs.getInt(_coinsKey);
    _gems.value = _prefs.getInt(_gemsKey);
  }

  Future<void> creditCoins(int amount, {required String reason}) =>
      _apply(Currency.coins, amount.abs(), reason);

  Future<bool> debitCoins(int amount, {required String reason}) async {
    if (amount.abs() > _coins.value) return false;
    await _apply(Currency.coins, -amount.abs(), reason);
    return true;
  }

  Future<void> creditGems(int amount, {required String reason}) =>
      _apply(Currency.gems, amount.abs(), reason);

  Future<bool> debitGems(int amount, {required String reason}) async {
    if (amount.abs() > _gems.value) return false;
    await _apply(Currency.gems, -amount.abs(), reason);
    return true;
  }

  List<WalletTransaction> get transactions {
    return _prefs
        .getStringList(_ledgerKey)
        .map((e) => WalletTransaction.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _apply(Currency currency, int delta, String reason) async {
    final notifier = currency == Currency.coins ? _coins : _gems;
    final key = currency == Currency.coins ? _coinsKey : _gemsKey;
    final next = notifier.value + delta;
    notifier.value = next;
    await _prefs.setInt(key, next);

    final tx = WalletTransaction(
      currency: currency,
      amount: delta,
      reason: reason,
      at: DateTime.now().toUtc(),
      balanceAfter: next,
    );
    await _appendLedger(tx);
    _analytics.onTransaction(tx);
  }

  Future<void> _appendLedger(WalletTransaction tx) async {
    final list = _prefs.getStringList(_ledgerKey).toList()
      ..add(jsonEncode(tx.toJson()));
    final trimmed = list.length > _ledgerCap
        ? list.sublist(list.length - _ledgerCap)
        : list;
    await _prefs.setStringList(_ledgerKey, trimmed);
  }

  void dispose() {
    _coins.dispose();
    _gems.dispose();
  }
}
