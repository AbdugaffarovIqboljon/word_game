import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';
import 'package:word_game/features/wallet/domain/wallet_analytics.dart';
import 'package:word_game/features/wallet/domain/wallet_transaction.dart';

class _CapturingAnalytics implements WalletAnalytics {
  final List<WalletTransaction> events = [];
  @override
  void onTransaction(WalletTransaction transaction) => events.add(transaction);
}

void main() {
  late PreferencesService prefs;
  late _CapturingAnalytics analytics;
  late WalletService wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    analytics = _CapturingAnalytics();
    wallet = WalletService(prefs: prefs, analytics: analytics)..load();
  });

  tearDown(() => wallet.dispose());

  test('starts empty', () {
    expect(wallet.coinBalance, 0);
    expect(wallet.gemBalance, 0);
  });

  test('credit increases balance and logs a transaction', () async {
    await wallet.creditCoins(40, reason: 'daily');
    expect(wallet.coinBalance, 40);
    expect(wallet.transactions, hasLength(1));
    expect(analytics.events.single.amount, 40);
  });

  test('debit is atomic — fails and changes nothing when insufficient', () async {
    await wallet.creditCoins(40, reason: 'daily');
    final ok = await wallet.debitCoins(100, reason: 'hint');
    expect(ok, isFalse);
    expect(wallet.coinBalance, 40);
  });

  test('successful debit reduces balance', () async {
    await wallet.creditCoins(40, reason: 'daily');
    final ok = await wallet.debitCoins(30, reason: 'hint');
    expect(ok, isTrue);
    expect(wallet.coinBalance, 10);
  });

  test('balances are reactive listenables', () async {
    var notified = 0;
    wallet.coins.addListener(() => notified++);
    await wallet.creditCoins(10, reason: 'x');
    expect(notified, 1);
    expect(wallet.coins.value, 10);
  });

  test('gems track independently', () async {
    await wallet.creditGems(50, reason: 'starter');
    expect(wallet.gemBalance, 50);
    expect(wallet.coinBalance, 0);
  });

  test('balances persist across reloads', () async {
    await wallet.creditCoins(75, reason: 'x');
    final reloaded = WalletService(prefs: prefs, analytics: analytics)..load();
    expect(reloaded.coinBalance, 75);
    reloaded.dispose();
  });
}
