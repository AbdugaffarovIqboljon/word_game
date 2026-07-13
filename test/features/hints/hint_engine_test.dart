import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/game_state.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/uzbek_alphabet.dart';
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

  group('absentCandidates', () {
    test('is every alphabet letter minus the answer letters', () {
      final candidates = HintEngine.absentCandidates(answer, {});
      final distinctAnswer = answer.toSet();
      expect(
        candidates,
        hasLength(UzbekAlphabet.letters.length - distinctAnswer.length),
      );
      expect(candidates.any(distinctAnswer.contains), isFalse);
    });

    test('excludes already-known letters', () {
      final known = {const LogicalLetter('z'), const LogicalLetter('x')};
      final candidates = HintEngine.absentCandidates(answer, known);
      expect(candidates.contains(const LogicalLetter('z')), isFalse);
      expect(candidates.contains(const LogicalLetter('x')), isFalse);
    });

    test('is empty when every non-answer letter is already known', () {
      final allAbsent = HintEngine.absentCandidates(answer, {}).toSet();
      expect(HintEngine.absentCandidates(answer, allAbsent), isEmpty);
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

    test('returns fewer than count when fewer qualify (min 1)', () {
      // Mark all-but-three of the absent letters so only three remain.
      final all = HintEngine.absentCandidates(answer, {});
      final marked = all.take(all.length - 3).toSet();
      final picked = HintEngine.pickAbsentLetters(answer, marked, count: 5);
      expect(picked, hasLength(3));
    });

    test('returns empty when none qualify', () {
      final all = HintEngine.absentCandidates(answer, {}).toSet();
      final picked = HintEngine.pickAbsentLetters(answer, all, count: 5);
      expect(picked, isEmpty);
    });
  });
}
