import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/guess.dart';
import 'package:word_game/core/game/domain/keyboard_aggregator.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';

LogicalLetter l(String v) => LogicalLetter(v);

Guess guess(List<String> letters, List<LetterResult> results) =>
    Guess(letters: letters.map(l).toList(), results: results);

void main() {
  const absent = LetterResult.absent;
  const present = LetterResult.present;
  const correct = LetterResult.correct;

  group('KeyboardAggregator priority (correct > present > absent)', () {
    test('present then correct upgrades to correct', () {
      final states = KeyboardAggregator.aggregate([
        guess(['a', 'b'], [present, absent]),
        guess(['a', 'b'], [correct, absent]),
      ]);
      expect(states[l('a')], correct);
    });

    test('correct then present does NOT downgrade', () {
      final states = KeyboardAggregator.aggregate([
        guess(['a', 'b'], [correct, absent]),
        guess(['a', 'b'], [present, absent]),
      ]);
      expect(states[l('a')], correct);
    });

    test('absent then present upgrades to present', () {
      final states = KeyboardAggregator.aggregate([
        guess(['a'], [absent]),
        guess(['a'], [present]),
      ]);
      expect(states[l('a')], present);
    });

    test('unguessed letters are absent from the map (stay default)', () {
      final states = KeyboardAggregator.aggregate([
        guess(['a'], [correct]),
      ]);
      expect(states.containsKey(l('z')), isFalse);
    });

    test('aggregates across compound letters too', () {
      final states = KeyboardAggregator.aggregate([
        guess(['sh', 'oʻ'], [absent, present]),
        guess(['sh', 'oʻ'], [present, correct]),
      ]);
      expect(states[l('sh')], present);
      expect(states[l('oʻ')], correct);
    });
  });
}
