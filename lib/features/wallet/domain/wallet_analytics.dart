import 'wallet_transaction.dart';

/// Analytics sink for wallet events. Every credit/debit fires
/// [onTransaction]; the real implementation (Firebase/Amplitude/etc.) is a
/// later work package. v1 wires [NoopWalletAnalytics].
abstract interface class WalletAnalytics {
  void onTransaction(WalletTransaction transaction);
}

/// No-op sink used until a real analytics backend is wired.
class NoopWalletAnalytics implements WalletAnalytics {
  const NoopWalletAnalytics();

  @override
  void onTransaction(WalletTransaction transaction) {}
}
