import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/features/daily/presentation/widgets/daily_header.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('DailyHeader packs 3 chips + 5 icon buttons at 360px with no '
      'overflow, even with large values (WS3, mandate B10)', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final coins = ValueNotifier<int>(12840);
    final gems = ValueNotifier<int>(2500);
    addTearDown(coins.dispose);
    addTearDown(gems.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DailyHeader(
                streak: 365,
                coins: coins,
                gems: gems,
                chestUnclaimed: true,
                onStreak: () {},
                onShop: () {},
                onStats: () {},
                onChest: () {},
                onRules: () {},
                onHint: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // No RenderFlex overflow, and all five nav icon buttons are present —
    // rules (?) and hint (💡) consolidated into the app bar (WS3).
    expect(tester.takeException(), isNull);
    expect(find.byIcon(AppIcons.stats), findsOneWidget);
    expect(find.byIcon(AppIcons.gift), findsOneWidget);
    expect(find.byIcon(AppIcons.help), findsOneWidget);
    expect(find.byIcon(AppIcons.hint), findsOneWidget);
    expect(find.byIcon(AppIcons.settings), findsOneWidget);
  });
}
