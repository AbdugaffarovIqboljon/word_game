import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/dictionary.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/features/daily/data/fallback_daily_puzzle_repository.dart';
import 'package:word_game/features/daily/domain/daily_puzzle_repository.dart';

/// Independent re-implementation of the `evaluate-guess` Edge Function's scoring
/// (index.ts): correct-first pass with a `used` array, then a `present` pass that
/// consumes each still-unused answer letter left-to-right. The offline evaluator
/// must agree with THIS for every guess/answer, so local play is byte-identical
/// to the server.
List<LetterResult> serverEvaluate(String answer, String guess) {
  final a = WordTokenizer.tokenize(answer).map((l) => l.value).toList();
  final g = WordTokenizer.tokenize(guess).map((l) => l.value).toList();
  final result = List<LetterResult>.filled(a.length, LetterResult.absent);
  final used = List<bool>.filled(a.length, false);
  for (var i = 0; i < g.length; i++) {
    if (g[i] == a[i]) {
      result[i] = LetterResult.correct;
      used[i] = true;
    }
  }
  for (var i = 0; i < g.length; i++) {
    if (result[i] == LetterResult.correct) continue;
    for (var j = 0; j < a.length; j++) {
      if (!used[j] && a[j] == g[i]) {
        result[i] = LetterResult.present;
        used[j] = true;
        break;
      }
    }
  }
  return result;
}

/// Bundled data source (the resident [Dictionary]) with a fixed answer per date
/// and a closed vocabulary, so offline scoring/validation is deterministic.
class _FakeBundle implements Dictionary {
  _FakeBundle({required this.answers, required this.vocab, this.number = 42});

  final Map<String, String> answers; // 'yyyy-mm-dd' -> answer word
  final Set<String> vocab; // valid guess keys
  final int number;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool contains(List<LogicalLetter> word) =>
      vocab.contains(WordTokenizer.keyOf(word));

  @override
  List<LogicalLetter> answerForDate(DateTime date) {
    final w = answers[_key(date)];
    return w == null ? const [] : WordTokenizer.tokenize(w);
  }

  @override
  String? definitionFor(List<LogicalLetter> word) => null;

  @override
  String? themeFor(List<LogicalLetter> word) => null;

  @override
  int puzzleNumberForDate(DateTime date) => number;
}

enum _Mode { online, offline, slow, notAWord }

/// Controllable primary: flips between a healthy server, an offline/5xx error,
/// a hang longer than the fallback timeout, and an authoritative not-a-word.
class _TogglePrimary implements DailyPuzzleRepository {
  _TogglePrimary(this._answers);

  final Map<String, String> _answers;
  _Mode mode = _Mode.online;
  int metaCalls = 0;
  int evalCalls = 0;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate) async {
    metaCalls++;
    switch (mode) {
      case _Mode.offline:
        throw const DailyPuzzleUnavailableException('offline');
      case _Mode.slow:
        await Future<void>.delayed(const Duration(seconds: 5));
        return _meta(puzzleDate);
      case _Mode.online:
      case _Mode.notAWord:
        return _meta(puzzleDate);
    }
  }

  DailyPuzzleMeta _meta(DateTime d) => DailyPuzzleMeta(
        puzzleNumber: 900, // distinct from the bundle so we can tell them apart
        puzzleDate: d,
        wordLength: 5,
        theme: 'server',
        lockedPrefixRaw: 'SE',
      );

  @override
  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  }) async {
    evalCalls++;
    switch (mode) {
      case _Mode.offline:
        throw const DailyPuzzleUnavailableException('offline');
      case _Mode.notAWord:
        throw const InvalidGuessWordException();
      case _Mode.slow:
        await Future<void>.delayed(const Duration(seconds: 5));
        return _score(puzzleDate, guess, revealOnFail);
      case _Mode.online:
        return _score(puzzleDate, guess, revealOnFail);
    }
  }

  GuessEvaluation _score(DateTime d, String guess, bool revealOnFail) {
    final answer = _answers[_key(d)]!;
    final results = serverEvaluate(answer, guess);
    final solved = results.every((r) => r == LetterResult.correct);
    return GuessEvaluation(
      results: results,
      solved: solved,
      answer: (solved || revealOnFail) ? answer.toUpperCase() : null,
    );
  }
}

void main() {
  final date = DateTime.utc(2026, 7, 16);
  const dateKey = '2026-07-16';

  // Duplicate-letter stress pairs (answer, guess) + a couple with compounds.
  const pairs = <List<String>>[
    ['salom', 'molla'],
    ['salom', 'sssss'],
    ['tepki', 'kette'],
    ['barak', 'araba'],
    ['kitob', 'kitob'],
    ['qalam', 'malaq'],
    ['shakar', 'karash'],
  ];

  FallbackDailyPuzzleRepository build(_TogglePrimary primary, _FakeBundle bundle) =>
      FallbackDailyPuzzleRepository(
        primary: primary,
        bundled: bundle,
        networkTimeout: const Duration(milliseconds: 200),
      );

  group('local scoring parity with the evaluate-guess algorithm', () {
    test('offline scoring equals the server algorithm for every pair', () async {
      for (final p in pairs) {
        final answer = p[0];
        final guess = p[1];
        // Only exercise equal-length, in-vocab guesses here (length mismatch has
        // its own not-a-word test below).
        if (WordTokenizer.tokenize(guess).length !=
            WordTokenizer.tokenize(answer).length) {
          continue;
        }
        final bundle = _FakeBundle(
          answers: {dateKey: answer},
          vocab: {
            WordTokenizer.keyOf(WordTokenizer.tokenize(guess)),
            WordTokenizer.keyOf(WordTokenizer.tokenize(answer)),
          },
        );
        final primary = _TogglePrimary({dateKey: answer})..mode = _Mode.offline;
        final repo = build(primary, bundle);

        final eval = await repo.evaluateGuess(
          puzzleDate: date,
          guess: guess,
          revealOnFail: false,
        );

        expect(
          eval.results,
          serverEvaluate(answer, guess),
          reason: 'offline "$guess" vs "$answer" must match the server rule',
        );
        expect(eval.solved, guess == answer);
        // Local scoring only, primary never produced a result.
        expect(primary.evalCalls, 1); // called once, then threw -> fallback
      }
    });
  });

  group('server authority + reveal', () {
    test('server not_a_word is authoritative — never falls back to local', () async {
      // Bundle WOULD accept the guess, but the online server rejected it: the
      // rejection must win (no local re-score).
      final bundle = _FakeBundle(
        answers: {dateKey: 'salom'},
        vocab: {WordTokenizer.keyOf(WordTokenizer.tokenize('molla'))},
      );
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.notAWord;
      final repo = build(primary, bundle);

      expect(
        () => repo.evaluateGuess(
            puzzleDate: date, guess: 'molla', revealOnFail: false),
        throwsA(isA<InvalidGuessWordException>()),
      );
    });

    test('offline reveals the answer on the final attempt', () async {
      final bundle = _FakeBundle(
        answers: {dateKey: 'salom'},
        vocab: {WordTokenizer.keyOf(WordTokenizer.tokenize('molla'))},
      );
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.offline;
      final repo = build(primary, bundle);

      final eval = await repo.evaluateGuess(
        puzzleDate: date,
        guess: 'molla',
        revealOnFail: true,
      );
      expect(eval.solved, isFalse);
      expect(WordTokenizer.tokenize(eval.answer!),
          WordTokenizer.tokenize('salom'));
    });

    test('a guess not in the bundled vocab is rejected offline', () async {
      final bundle = _FakeBundle(answers: {dateKey: 'salom'}, vocab: const {});
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.offline;
      final repo = build(primary, bundle);
      expect(
        () => repo.evaluateGuess(
            puzzleDate: date, guess: 'molla', revealOnFail: false),
        throwsA(isA<InvalidGuessWordException>()),
      );
    });
  });

  group('latency fallback', () {
    test('a hang beyond the timeout falls back to bundled scoring', () async {
      final bundle = _FakeBundle(
        answers: {dateKey: 'salom'},
        vocab: {WordTokenizer.keyOf(WordTokenizer.tokenize('molla'))},
      );
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.slow;
      final repo = build(primary, bundle);

      final sw = Stopwatch()..start();
      final eval = await repo.evaluateGuess(
        puzzleDate: date,
        guess: 'molla',
        revealOnFail: false,
      );
      sw.stop();
      expect(eval.results, serverEvaluate('salom', 'molla'));
      // Fell back at ~200ms, nowhere near the 5s primary hang.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('fetchMeta falls back to the bundled puzzle number when offline',
        () async {
      final bundle = _FakeBundle(
        answers: {dateKey: 'salom'},
        vocab: const {},
        number: 6,
      );
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.offline;
      final repo = build(primary, bundle);

      final meta = await repo.fetchMeta(date);
      expect(meta.puzzleNumber, 6); // bundle, not the server's 900
      expect(meta.wordLength, 5);
      expect(meta.lockedPrefixRaw, 'sa');
    });

    test('fetchMeta online returns the server meta (not the bundle)', () async {
      final bundle = _FakeBundle(
          answers: {dateKey: 'salom'}, vocab: const {}, number: 6);
      final primary = _TogglePrimary({dateKey: 'salom'})..mode = _Mode.online;
      final repo = build(primary, bundle);

      final meta = await repo.fetchMeta(date);
      expect(meta.puzzleNumber, 900); // server wins while reachable
      expect(meta.theme, 'server');
    });
  });
}
