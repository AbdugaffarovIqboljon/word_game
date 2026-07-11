import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/guess_evaluator.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';

/// Builds a guess/answer from an explicit list of canonical letters so
/// compound behavior is fully controlled (no accidental digraph merging).
List<LogicalLetter> ll(List<String> xs) => xs.map(LogicalLetter.new).toList();

/// Compact rendering of results: A=absent, P=present, C=correct.
String code(List<LetterResult> rs) => rs
    .map(
      (r) => switch (r) {
        LetterResult.absent => 'A',
        LetterResult.present => 'P',
        LetterResult.correct => 'C',
      },
    )
    .join();

class _Case {
  const _Case(this.name, this.answer, this.guess, this.expected);
  final String name;
  final List<String> answer;
  final List<String> guess;
  final String expected;
}

void main() {
  // 29 cases spanning every rule the evaluator must get right.
  const cases = <_Case>[
    // ── all-correct / all-absent ──
    _Case('all correct', ['q', 'a', 'l', 'a', 'm'], ['q', 'a', 'l', 'a', 'm'], 'CCCCC'),
    _Case('all absent', ['q', 'p', 't', 'u', 'm'], ['b', 'd', 'e', 'r', 'k'], 'AAAAA'),

    // ── duplicate letter in GUESS, single in ANSWER ──
    _Case('dup guess, first correct', ['a', 'b', 'c', 'd', 'e'], ['a', 'a', 'x', 'y', 'z'], 'CAAAA'),
    _Case('dup guess, first present', ['a', 'b', 'c', 'd', 'e'], ['x', 'a', 'a', 'y', 'z'], 'APAAA'),
    _Case('triple guess, one correct', ['a', 'b', 'c', 'd', 'e'], ['a', 'a', 'a', 'y', 'z'], 'CAAAA'),

    // ── duplicate letter in ANSWER ──
    _Case('dup answer, one correct guess', ['a', 'a', 'b', 'c', 'd'], ['a', 'x', 'y', 'z', 'w'], 'CAAAA'),
    _Case('dup answer, one present guess', ['a', 'a', 'b', 'c', 'd'], ['x', 'y', 'a', 'z', 'w'], 'AAPAA'),
    _Case('dup answer, two correct', ['a', 'a', 'b', 'c', 'd'], ['a', 'a', 'x', 'y', 'z'], 'CCAAA'),
    _Case('dup answer, correct + present', ['a', 'a', 'b', 'c', 'd'], ['a', 'x', 'a', 'y', 'z'], 'CAPAA'),
    _Case('triple answer, two correct', ['a', 'a', 'a', 'b', 'c'], ['a', 'a', 'x', 'y', 'z'], 'CCAAA'),
    _Case('scattered answer dup, all-a guess', ['a', 'b', 'a', 'c', 'a'], ['a', 'a', 'a', 'a', 'a'], 'CACAC'),

    // ── compound letters ──
    _Case('compound present (sh)', ['q', 'u', 'y', 'o', 'sh'], ['sh', 'a', 'k', 'a', 'r'], 'PAAAA'),
    _Case('duplicate compound (sh)', ['sh', 'a', 'sh', 'o', 'q'], ['sh', 'x', 'sh', 'y', 'z'], 'CACAA'),
    _Case('oʻ correct, o present', ['oʻ', 'r', 'm', 'o', 'n'], ['oʻ', 'o', 'm', 'x', 'n'], 'CPCAC'),
    _Case('oʻ != o distinctness', ['oʻ', 'a', 'b', 'c', 'd'], ['o', 'a', 'b', 'c', 'd'], 'ACCCC'),
    _Case('all-correct compound word (ch)', ['ch', 'i', 'r', 'o', 'q'], ['ch', 'i', 'r', 'o', 'q'], 'CCCCC'),
    _Case('gʻ present/correct mix', ['y', 'i', 'gʻ', 'i', 'n'], ['gʻ', 'i', 'i', 'y', 'n'], 'PCPPC'),
    _Case('all-correct compound word (gʻ)', ['o', 'gʻ', 'r', 'i', 'q'], ['o', 'gʻ', 'r', 'i', 'q'], 'CCCCC'),

    // ── mixed realistic words ──
    _Case('qalam vs salom', ['q', 'a', 'l', 'a', 'm'], ['s', 'a', 'l', 'o', 'm'], 'ACCAC'),
    _Case('salom vs somon', ['s', 'a', 'l', 'o', 'm'], ['s', 'o', 'm', 'o', 'n'], 'CAPCA'),
    _Case('bodom vs bahor', ['b', 'o', 'd', 'o', 'm'], ['b', 'a', 'h', 'o', 'r'], 'CAACA'),
    _Case('tuman vs tarix', ['t', 'u', 'm', 'a', 'n'], ['t', 'a', 'r', 'i', 'x'], 'CPAAA'),

    // ── tricky duplicate ordering ──
    _Case('present before correct dup', ['a', 'b', 'c', 'd', 'e'], ['b', 'b', 'a', 'a', 'a'], 'ACPAA'),
    _Case('two-pairs anagram-ish', ['a', 'a', 'b', 'b', 'c'], ['b', 'b', 'a', 'a', 'c'], 'PPPPC'),
    _Case('two-pairs with matches', ['a', 'a', 'b', 'b', 'c'], ['a', 'b', 'a', 'b', 'c'], 'CPPCC'),

    // ── full anagram / reversal ──
    _Case('full anagram all present', ['a', 'b', 'c', 'd', 'e'], ['b', 'c', 'd', 'e', 'a'], 'PPPPP'),
    _Case('reversal, middle correct', ['a', 'b', 'c', 'd', 'e'], ['e', 'd', 'c', 'b', 'a'], 'PPCPP'),

    // ── more duplicate coverage ──
    _Case('two answer, three guess', ['a', 'a', 'b', 'c', 'd'], ['a', 'a', 'a', 'x', 'y'], 'CCAAA'),
    _Case('scattered answer dup 2', ['a', 'b', 'a', 'c', 'd'], ['a', 'a', 'a', 'a', 'a'], 'CACAA'),
  ];

  group('GuessEvaluator two-pass rules', () {
    for (final c in cases) {
      test('${c.name} (${c.guess.join()} vs ${c.answer.join()})', () {
        final result = GuessEvaluator.evaluate(ll(c.guess), ll(c.answer));
        expect(code(result), c.expected);
      });
    }

    test('exactly one present when guess has two of a single-answer letter', () {
      final r = GuessEvaluator.evaluate(
        ll(['a', 'a', 'x', 'y', 'z']),
        ll(['x', 'a', 'b', 'c', 'd']),
      );
      // Only one of the two guessed 'a's should be yellow.
      expect(r.where((e) => e == LetterResult.present), hasLength(1));
    });

    test('throws on length mismatch', () {
      expect(
        () => GuessEvaluator.evaluate(ll(['a', 'b', 'c', 'd']), ll(['a', 'b', 'c', 'd', 'e'])),
        throwsArgumentError,
      );
    });
  });
}
