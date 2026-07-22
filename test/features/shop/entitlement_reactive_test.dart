import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/analytics/analytics_service.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/features/bonus/presentation/widgets/bonus_button.dart';
import 'package:word_game/features/shop/data/purchase_fulfiller.dart';
import 'package:word_game/features/shop/data/purchases_repository.dart';
import 'package:word_game/features/shop/domain/sku_ids.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

/// WS1 — buying remove-ads must swap the daily result CTA from the gold upsell
/// to "Yana yechish" in place, the instant fulfillment lands on the purchase
/// stream, with no reload. The CTA binds to the entitlement listenable; this
/// drives the real fulfillment layer and asserts the bound widget reacts.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late PreferencesService prefs;
  late WalletService wallet;
  late PurchasesRepository purchases;
  late PurchaseFulfiller fulfiller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
    purchases = PurchasesRepository(prefs)..load();
    fulfiller = PurchaseFulfiller(
      wallet: wallet,
      purchases: purchases,
      config: const GameConfig(),
      analytics: const NoopAnalyticsService(),
    );
  });

  testWidgets('fulfilling remove-ads swaps the CTA live (no reload)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Mirrors the daily result CTA binding: bound to the entitlement
          // listenable exposed by the fulfillment layer.
          body: ValueListenableBuilder<bool>(
            valueListenable: purchases.removeAds,
            builder: (context, isPro, _) => BonusButton(
              isPro: isPro,
              onPlay: () {},
              onUpsell: () {},
            ),
          ),
        ),
      ),
    );

    // Free: gold premium upsell (sparkles), never the play/refresh CTA.
    expect(find.byIcon(AppIcons.sparkles), findsOneWidget);
    expect(find.byIcon(AppIcons.refresh), findsNothing);

    // A purchase completes on the stream → fulfilled centrally.
    await fulfiller.fulfill(SkuIds.removeAds);
    await tester.pump();

    // CTA has swapped in place — no route re-entry.
    expect(find.byIcon(AppIcons.refresh), findsOneWidget);
    expect(find.byIcon(AppIcons.sparkles), findsNothing);
    expect(purchases.removeAds.value, isTrue);
  });
}
