import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/theme/app_icons.dart';
import 'package:word_game/core/game/domain/guess.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/presentation/board_controller.dart';
import 'package:word_game/core/game/presentation/clean_hint_pulse.dart';
import 'package:word_game/core/game/presentation/widgets/game_board.dart';
import 'package:word_game/core/game/presentation/widgets/game_keyboard.dart';
import 'package:word_game/core/game/presentation/widgets/invalid_word_toast.dart';

List<LogicalLetter> ll(List<String> xs) => xs.map(LogicalLetter.new).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('GameKeyboard', () {
    testWidgets('renders all letter + action keys and fires callbacks', (
      tester,
    ) async {
      final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({});
      LogicalLetter? tapped;
      var enterCount = 0;
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameKeyboard(
              keyStates: states,
              onLetter: (l) => tapped = l,
              onEnter: () => enterCount++,
              onDelete: () => deleteCount++,
            ),
          ),
        ),
      );

      expect(find.text('Q'), findsOneWidget);
      expect(find.text('Oʻ'), findsOneWidget);
      expect(find.text('Ng'), findsOneWidget);
      // ENTER now renders as the ↵ icon (component_spec (a)); ⌫ stays a glyph.
      expect(find.text('ENTER'), findsNothing);
      expect(find.byIcon(AppIcons.enter), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);

      await tester.tap(find.text('Q'));
      expect(tapped, const LogicalLetter('q'));

      await tester.tap(find.byIcon(AppIcons.enter));
      await tester.tap(find.text('⌫'));
      expect(enterCount, 1);
      expect(deleteCount, 1);

      states.dispose();
    });

    testWidgets('enabledLetters restricts which letter keys are tappable', (
      tester,
    ) async {
      final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({});
      addTearDown(states.dispose);
      final tapped = <LogicalLetter>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameKeyboard(
              keyStates: states,
              enabledLetters: {const LogicalLetter('q')},
              onLetter: tapped.add,
              onEnter: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('A')); // disabled → ignored
      await tester.tap(find.text('Q')); // enabled → fires
      expect(tapped, const [LogicalLetter('q')]);
    });

    testWidgets('clean-hint pulse fades keys to absent without error', (
      tester,
    ) async {
      final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({});
      final pulse = ValueNotifier<CleanHintPulse?>(null);
      addTearDown(states.dispose);
      addTearDown(pulse.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameKeyboard(
              keyStates: states,
              cleanPulse: pulse,
              onLetter: (_) {},
              onEnter: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      final cleaned = ll(['x', 'v', 'b']);
      pulse.value = CleanHintPulse(letters: cleaned, nonce: 1);
      states.value = {for (final l in cleaned) l: LetterResult.absent};
      // Advance past the staggered fade (3 × 60ms + 200ms fade).
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('GameBoard', () {
    testWidgets('renders typing input then reveals a row without error', (
      tester,
    ) async {
      final controller = BoardController(rows: 6, columns: 5);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: GameBoard(controller: controller)))),
      );

      controller.setInput(0, ll(['q', 'a']));
      await tester.pump(); // start the type-pop
      // The typed letter appears at the pop peak (~55ms) — advance past it.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      controller.revealRow(
        0,
        Guess(
          letters: ll(['q', 'a', 'l', 'a', 'm']),
          results: const [
            LetterResult.correct,
            LetterResult.present,
            LetterResult.absent,
            LetterResult.absent,
            LetterResult.correct,
          ],
        ),
      );
      // Step the 100ms stagger (×5) + 150ms flip frame-by-frame so each tile's
      // reveal timer fires and its flip advances past the 50% color swap.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('L'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shake runs and settles without error', (tester) async {
      final controller = BoardController(rows: 6, columns: 5);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: GameBoard(controller: controller)))),
      );

      controller.setInput(0, ll(['x', 'y', 'z', 'w', 'v']));
      await tester.pump();
      controller.shakeRow(0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  group('InvalidWordToast', () {
    testWidgets('appears then auto-dismisses after 1.4s', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => InvalidWordToast.show(
                    context,
                    message: 'Soʻz lugʻatda yoʻq',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump(); // insert
      await tester.pump(const Duration(milliseconds: 200)); // fade in
      expect(find.text('Soʻz lugʻatda yoʻq'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400)); // hold
      await tester.pump(const Duration(milliseconds: 200)); // fade out + remove
      expect(find.text('Soʻz lugʻatda yoʻq'), findsNothing);
    });
  });
}
