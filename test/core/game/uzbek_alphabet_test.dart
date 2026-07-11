import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/uzbek_alphabet.dart';

void main() {
  group('UzbekAlphabet', () {
    test('has exactly 29 letters', () {
      expect(UzbekAlphabet.letters, hasLength(29));
    });

    test('includes all 5 compound letters', () {
      final values = UzbekAlphabet.letters.map((l) => l.value).toSet();
      expect(values.containsAll(const {'oʻ', 'gʻ', 'sh', 'ch', 'ng'}), isTrue);
    });

    test('has no standalone c or w', () {
      final values = UzbekAlphabet.letters.map((l) => l.value).toSet();
      expect(values.contains('c'), isFalse);
      expect(values.contains('w'), isFalse);
    });

    test('isLetter recognizes members and rejects non-members', () {
      expect(UzbekAlphabet.isLetter('q'), isTrue);
      expect(UzbekAlphabet.isLetter('sh'), isTrue);
      expect(UzbekAlphabet.isLetter('c'), isFalse);
    });

    test('normalizeApostrophes is idempotent', () {
      const raw = "o'rmon";
      final once = UzbekAlphabet.normalizeApostrophes(raw);
      final twice = UzbekAlphabet.normalizeApostrophes(once);
      expect(once, twice);
      expect(once.contains(UzbekAlphabet.turnedComma), isTrue);
    });
  });
}
