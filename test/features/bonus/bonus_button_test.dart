import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/features/bonus/presentation/widgets/bonus_button.dart';

/// WS3 gating: pro users play a bonus word; free users are routed to the shop
/// upsell (the button never starts a bonus for them).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('pro user: tapping starts a bonus word', (tester) async {
    var played = 0, upsold = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonusButton(
            isPro: true,
            onPlay: () => played++,
            onUpsell: () => upsold++,
          ),
        ),
      ),
    );

    expect(find.byIcon(AppIcons.lock), findsNothing); // no padlock for pro
    await tester.tap(find.byType(BonusButton));
    expect(played, 1);
    expect(upsold, 0);
  });

  testWidgets('free user: premium CTA, tapping opens the upsell (no bonus)',
      (tester) async {
    var played = 0, upsold = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BonusButton(
            isPro: false,
            onPlay: () => played++,
            onUpsell: () => upsold++,
          ),
        ),
      ),
    );

    // Free users see the gold premium CTA (sparkles), not the play button —
    // the earlier padlock treatment was redesigned into this upsell variant.
    expect(find.byIcon(AppIcons.sparkles), findsOneWidget);
    expect(find.byIcon(AppIcons.refresh), findsNothing);
    await tester.tap(find.byType(BonusButton));
    expect(upsold, 1);
    expect(played, 0); // never starts a bonus for a free user
  });
}
