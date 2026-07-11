import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/game_state.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/features/hints/domain/hint_engine.dart';

List<LogicalLetter> ll(List<String> xs) => xs.map(LogicalLetter.new).toList();

void main() {
  final answer = ll(['q', 'a', 'l', 'a', 'm']);

  group('nextCorrectLetter', () {
    test('reveals the letter for the next empty slot', () {
      final game = GameState.playing(answer: answer);
      expect(HintEngine.nextCorrectLetter(game), const LogicalLetter('q'));
    });

    test('advances as letters are typed', () {
      var game = GameState.playing(answer: answer);
      game = game.addLetter(const LogicalLetter('q'));
      expect(HintEngine.nextCorrectLetter(game), const LogicalLetter('a'));
    });

    test('returns null when the row is full', () {
      var game = GameState.playing(answer: answer);
      for (final l in answer) {
        game = game.addLetter(l);
      }
      expect(HintEngine.nextCorrectLetter(game), isNull);
    });

    test('returns null when not playing', () {
      const game = GameState.idle();
      expect(HintEngine.nextCorrectLetter(game), isNull);
    });
  });

  group('pickAbsentLetters', () {
    test('picks letters that are not in the answer', () {
      final picked = HintEngine.pickAbsentLetters(
        answer,
        {},
        count: 5,
      );
      expect(picked, hasLength(5));
      final answerSet = answer.toSet();
      expect(picked.any(answerSet.contains), isFalse);
    });

    test('skips already-marked letters', () {
      final marked = {const LogicalLetter('z')};
      final picked = HintEngine.pickAbsentLetters(answer, marked, count: 5);
      expect(picked.contains(const LogicalLetter('z')), isFalse);
    });
  });
}
