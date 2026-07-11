import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/uzbek_alphabet.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';

void main() {
  group('WordTokenizer greedy compound matching', () {
    List<String> tok(String s) =>
        WordTokenizer.tokenize(s).map((l) => l.value).toList();

    test('single letters', () {
      expect(tok('qalam'), ['q', 'a', 'l', 'a', 'm']);
    });

    test('sh digraph collapses to one letter', () {
      expect(tok('quyosh'), ['q', 'u', 'y', 'o', 'sh']);
    });

    test('ch digraph collapses to one letter', () {
      expect(tok('chiroq'), ['ch', 'i', 'r', 'o', 'q']);
    });

    test('ng digraph collapses to one letter', () {
      expect(tok('tanga'), ['t', 'a', 'ng', 'a']);
    });

    test('oʻ with U+02BB is one letter distinct from o', () {
      expect(tok('oʻrmon'), ['oʻ', 'r', 'm', 'o', 'n']);
      expect(tok('oʻrmon').first, 'oʻ');
      expect(tok('oʻrmon')[3], 'o');
    });

    test('gʻ with U+02BB is one letter', () {
      expect(tok('ogʻriq'), ['o', 'gʻ', 'r', 'i', 'q']);
    });
  });

  group('WordTokenizer apostrophe normalization', () {
    List<String> tok(String s) =>
        WordTokenizer.tokenize(s).map((l) => l.value).toList();

    test("straight apostrophe ' normalizes to U+02BB", () {
      expect(tok("o'rmon"), ['oʻ', 'r', 'm', 'o', 'n']);
    });

    test('right single quote ’ normalizes to U+02BB', () {
      expect(tok('o’rmon'), ['oʻ', 'r', 'm', 'o', 'n']);
    });

    test('modifier apostrophe ʼ (U+02BC) normalizes to U+02BB', () {
      expect(tok('oʼrmon'), ['oʻ', 'r', 'm', 'o', 'n']);
    });

    test('backtick ` normalizes to U+02BB in gʻ', () {
      expect(tok('og`riq'), ['o', 'gʻ', 'r', 'i', 'q']);
    });

    test('already-canonical U+02BB is unchanged', () {
      expect(UzbekAlphabet.normalizeApostrophes('oʻ'), 'oʻ');
    });
  });

  test('tokenizer trims and lowercases', () {
    expect(
      WordTokenizer.tokenize('  QALAM  ').map((l) => l.value).toList(),
      ['q', 'a', 'l', 'a', 'm'],
    );
  });

  test('keyOf produces an unambiguous joined key', () {
    final a = WordTokenizer.tokenize('quyosh');
    expect(WordTokenizer.keyOf(a), 'q|u|y|o|sh');
  });
}
