import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/core/widgets/app_dialog.dart';
import 'package:word_game/core/widgets/primary_button.dart';
import 'package:word_game/features/ads/presentation/reward_dialogs.dart';

/// WS6 — the reward-granted dialog credits nothing itself; it just celebrates,
/// then auto-dismisses. No "Oldim" button, and a tap anywhere closes it early.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> open(WidgetTester tester, {int autoCloseMs = 400}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () =>
                    showRewardGranted(context, amount: 150, autoCloseMs: autoCloseMs),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // show dialog
    await tester.pump(const Duration(milliseconds: 16)); // first anim frame
  }

  testWidgets('has no Oldim/CTA button and shows the coin badge', (tester) async {
    await open(tester);
    expect(find.byType(AppDialogCard), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.byIcon(AppIcons.coins), findsOneWidget);
    // Drain the auto-close timer so the test ends clean.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('auto-dismisses after the configured window', (tester) async {
    await open(tester, autoCloseMs: 400);
    expect(find.byType(AppDialogCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogCard), findsNothing);
  });

  testWidgets('a tap dismisses it early', (tester) async {
    await open(tester, autoCloseMs: 5000);
    expect(find.byType(AppDialogCard), findsOneWidget);
    await tester.tap(find.byType(AppDialogCard));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialogCard), findsNothing);
  });
}
