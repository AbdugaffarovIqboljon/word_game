import '../../../core/analytics/analytics_service.dart';
import '../domain/wallet_analytics.dart';
import '../domain/wallet_transaction.dart';

/// Adapts the wallet's [WalletAnalytics] hook onto the app-wide
/// [AnalyticsService], translating each ledger entry into an `economy_tx`
/// event. This is the zero-touch path: [WalletService] already fires
/// `onTransaction` for every credit/debit, so wiring this bridge is all that is
/// needed to emit economy analytics — no gameplay code changes.
class AnalyticsWalletBridge implements WalletAnalytics {
  const AnalyticsWalletBridge(this._analytics);

  final AnalyticsService _analytics;

  @override
  void onTransaction(WalletTransaction transaction) {
    _analytics.economyTx(
      currency: transaction.currency.name,
      amount: transaction.amount.abs(),
      direction: transaction.amount >= 0 ? 'credit' : 'debit',
      source: transaction.reason,
    );
  }
}
