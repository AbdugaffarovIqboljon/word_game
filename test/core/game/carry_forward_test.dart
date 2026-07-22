import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/game_state.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';

/// WS2 carry-forward rule: only `correct` (green) letters carry into the next
/// row (as locked tiles); `present` (amber) letters are never pre-filled.
void main() {
  GameState typed(List<LogicalLetter> word) {
    var g = GameState.playing(answer: const [], wordLength: 5, maxAttempts: 5);
    for (final l in word) {
      g = g.addLetter(l);
    }
    return g;
  }

  test('submitWithServerResults locks greens only; ambers do not seed the row',
      () {
    final guess = WordTokenizer.tokenize('kitob');
    // k=correct, i=present, t=absent, o=absent, b=present
    final next = typed(guess).submitWithServerResults(const [
      LetterResult.correct,
      LetterResult.present,
      LetterResult.absent,
      LetterResult.absent,
      LetterResult.present,
    ]);

    // Only column 0 (the green K) is locked and carried into the next row.
    expect(next.lockedPositions, {0: guess[0]});
    expect(next.input, [guess[0]]); // seeded with the green only — no ambers
  });

  test('local-eval carry-forward also locks greens only', () {
    final answer = WordTokenizer.tokenize('qalam');
    var g = GameState.playing(answer: answer, wordLength: 5, maxAttempts: 5);
    // Guess "qatim" vs "qalam": q green(0), a green(1), t/i absent, m green(4).
    for (final l in WordTokenizer.tokenize('qatim')) {
      g = g.addLetter(l);
    }
    final next = g.submitWithCarryForward();
    expect(next.lockedPositions.keys.toList()..sort(), [0, 1, 4]);
    // Seeding is contiguous from column 0, so it stops at the first gap (col 2):
    // the green at 4 is locked but not part of the seeded prefix.
    expect(next.input, [answer[0], answer[1]]);
  });

  test('duplicate-letter greens each lock their own column', () {
    final answer = WordTokenizer.tokenize('qalam'); // two "a"s, at 1 and 3
    var g = GameState.playing(answer: answer, wordLength: 5, maxAttempts: 5);
    // Guess "aaaaa": the two "a" columns (1, 3) go green, the rest absent.
    for (final l in WordTokenizer.tokenize('aaaaa')) {
      g = g.addLetter(l);
    }
    final next = g.submitWithCarryForward();
    expect(next.lockedPositions.keys.toList()..sort(), [1, 3]);
    // Column 0 is not green, so nothing is pre-filled (no amber seeding at all).
    expect(next.input, isEmpty);
  });
}
