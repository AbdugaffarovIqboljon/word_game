import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/presentation/widgets/known_letters_strip.dart';

/// WS2: amber (`present`) letters are no longer pre-filled into board tiles —
/// they surface in the "Soʻzda bor:" strip, deduped, in alphabet order, and a
/// letter leaves the strip the instant it is confirmed green.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  LogicalLetter l(String v) => LogicalLetter(v);

  Future<void> pumpStrip(
    WidgetTester tester,
    ValueNotifier<Map<LogicalLetter, LetterResult>> states,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KnownLettersStrip(keyStates: states)),
      ),
    );
  }

  testWidgets('shows only present letters, in alphabet order, excluding '
      'absent and correct', (tester) async {
    // 's' (kb index 11) comes before 'l' (index 18); 'k' (index 17) absent and
    // 'q' (index 0) correct must not appear.
    final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({
      l('l'): LetterResult.present,
      l('s'): LetterResult.present,
      l('k'): LetterResult.absent,
      l('q'): LetterResult.correct,
    });
    addTearDown(states.dispose);
    await pumpStrip(tester, states);

    expect(find.text('S'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('K'), findsNothing);
    expect(find.text('Q'), findsNothing);

    // Alphabet order: S is rendered to the left of L.
    final sx = tester.getTopLeft(find.text('S')).dx;
    final lx = tester.getTopLeft(find.text('L')).dx;
    expect(sx, lessThan(lx));
  });

  testWidgets('a letter promoted present → correct is removed from the strip',
      (tester) async {
    final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({
      l('a'): LetterResult.present,
      l('l'): LetterResult.present,
    });
    addTearDown(states.dispose);
    await pumpStrip(tester, states);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);

    // 'a' turns green on a later guess → leaves the strip; 'l' stays.
    states.value = {
      l('a'): LetterResult.correct,
      l('l'): LetterResult.present,
    };
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('duplicate present letter renders a single chip', (tester) async {
    // Aggregated keyboard state is keyed by letter, so a word with the same
    // letter twice (one present) yields exactly one strip chip.
    final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({
      l('a'): LetterResult.present,
    });
    addTearDown(states.dispose);
    await pumpStrip(tester, states);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('empty / no-present state collapses to nothing', (tester) async {
    final states = ValueNotifier<Map<LogicalLetter, LetterResult>>({
      l('k'): LetterResult.absent,
      l('q'): LetterResult.correct,
    });
    addTearDown(states.dispose);
    await pumpStrip(tester, states);
    // No chips at all → the strip shrinks to a zero-size box.
    expect(tester.getSize(find.byType(KnownLettersStrip)), Size.zero);
  });
}
