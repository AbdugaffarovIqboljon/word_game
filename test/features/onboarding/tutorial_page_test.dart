import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/game/presentation/widgets/game_board.dart';
import 'package:word_game/core/game/presentation/widgets/keyboard_key_button.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/features/onboarding/presentation/tutorial_page.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('walks Beat 1 → Beat 2 → Beat 3 with the restricted keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TutorialPage(fromOnboarding: false)),
    );
    await tester.pump();

    // Beat 1: the keyboard is present; type the guided word OLTIN.
    expect(find.byIcon(AppIcons.enter), findsOneWidget);
    for (final glyph in const ['O', 'L', 'T', 'I', 'N']) {
      await tester.tap(find.widgetWithText(KeyboardKeyButton, glyph));
      await tester.pump();
    }

    // Submit → real flip → after the reveal we advance to the teach beat.
    await tester.tap(find.byIcon(AppIcons.enter));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 400));

    // Beat 2: the keyboard is hidden; tap through the three color callouts.
    expect(find.byIcon(AppIcons.enter), findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(GameBoard));
      await tester.pump();
    }

    // Beat 3: the keyboard is fully back and the puzzle is playable.
    expect(find.byIcon(AppIcons.enter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
