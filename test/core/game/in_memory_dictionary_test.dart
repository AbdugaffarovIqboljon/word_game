import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';

void main() {
  final dict = InMemoryDictionary();

  group('InMemoryDictionary contains', () {
    test('recognizes a seeded word', () {
      expect(dict.contains(WordTokenizer.tokenize('qalam')), isTrue);
    });

    test('recognizes a seeded word typed with a straight apostrophe', () {
      expect(dict.contains(WordTokenizer.tokenize("o'rmon")), isTrue);
    });

    test('rejects a non-seeded word', () {
      expect(dict.contains(WordTokenizer.tokenize('zzzzz')), isFalse);
    });
  });

  group('InMemoryDictionary answerForDate', () {
    test('is deterministic for the same date', () {
      final date = DateTime(2026, 7, 10);
      expect(dict.answerForDate(date), dict.answerForDate(date));
    });

    test('every seeded answer tokenizes to 5 logical letters', () {
      // Walk a full cycle of days and assert length.
      for (var i = 0; i < 40; i++) {
        final date = DateTime(2024, 1, 1).add(Duration(days: i));
        expect(dict.answerForDate(date), hasLength(5));
      }
    });

    test('answer changes across the schedule (not a constant)', () {
      final a = dict.answerForDate(DateTime(2024, 1, 1));
      final b = dict.answerForDate(DateTime(2024, 1, 2));
      expect(a == b, isFalse);
    });
  });

  group('InMemoryDictionary metadata', () {
    test('puzzle number is 1 on the epoch and increases daily', () {
      expect(dict.puzzleNumberForDate(DateTime.utc(2024, 1, 1)), 1);
      expect(dict.puzzleNumberForDate(DateTime.utc(2024, 1, 2)), 2);
    });

    test('definitions exist for seeded words', () {
      expect(dict.definitionFor(WordTokenizer.tokenize('qalam')), isNotNull);
    });
  });
}
