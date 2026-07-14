import 'package:equatable/equatable.dart';

import 'guess.dart';
import 'guess_evaluator.dart';
import 'keyboard_aggregator.dart';
import 'letter_result.dart';
import 'logical_letter.dart';

/// Lifecycle of a single puzzle.
enum GameStatus { idle, playing, won, lost }

/// Immutable snapshot of one puzzle in progress. All transitions are pure
/// functions returning a new [GameState]; the evaluator lives inside
/// [submit] so the engine is fully self-contained (dictionary *validity* is
/// checked by the caller before submitting — an invalid word triggers a shake,
/// not a submission).
class GameState extends Equatable {
  const GameState({
    required this.answer,
    required this.guesses,
    required this.input,
    required this.status,
    required this.wordLength,
    required this.maxAttempts,
    this.lockedPrefix = const [],
    this.lockedPositions = const {},
    this.prefillPositions = const {},
  });

  /// Pre-load state: no answer, nothing playable.
  const GameState.idle({this.wordLength = 5, this.maxAttempts = 5})
    : answer = const [],
      guesses = const [],
      input = const [],
      status = GameStatus.idle,
      lockedPrefix = const [],
      lockedPositions = const {},
      prefillPositions = const {};

  /// A fresh, playable puzzle for [answer].
  ///
  /// [lockedPrefix] (WS4) are leading letters that are revealed and locked from
  /// the start: the row is pre-staged with them, they cannot be deleted, and they
  /// count as submitted-correct. With `reveal_first_letter` on this is
  /// `[answer.first]`, so every row begins on the answer's green first letter.
  /// Seeds [lockedPositions] from [lockedPrefix] (positions `0..prefix.length-1`)
  /// so [addLetter]/[removeLetter] treat it identically to a carried-forward lock.
  factory GameState.playing({
    required List<LogicalLetter> answer,
    int wordLength = 5,
    int maxAttempts = 5,
    List<LogicalLetter> lockedPrefix = const [],
  }) {
    final locked = <int, LogicalLetter>{
      for (var i = 0; i < lockedPrefix.length; i++) i: lockedPrefix[i],
    };
    return GameState(
      answer: answer,
      guesses: const [],
      input: _seedInput(wordLength, locked, const {}),
      status: GameStatus.playing,
      wordLength: wordLength,
      maxAttempts: maxAttempts,
      lockedPrefix: lockedPrefix,
      lockedPositions: locked,
      prefillPositions: const {},
    );
  }

  final List<LogicalLetter> answer;
  final List<Guess> guesses;
  final List<LogicalLetter> input; // current, unsubmitted row (starts on lockedPrefix)
  final GameStatus status;
  final int wordLength;
  final int maxAttempts;

  /// Revealed, locked leading letters (WS4). Empty when the reveal is off.
  final List<LogicalLetter> lockedPrefix;

  /// Board positions whose letter is fixed and non-editable: the WS4
  /// [lockedPrefix] plus, for modes that opt into [submitWithCarryForward], any
  /// position found `correct` in a prior guess. Never shrinks once set.
  final Map<int, LogicalLetter> lockedPositions;

  /// Board positions pre-filled with a convenience suggestion (a `present`
  /// letter from the last guess, carried into the same position) that the user
  /// may freely overwrite or delete. Only populated by [submitWithCarryForward];
  /// replaced wholesale on every such submit (never accumulated).
  final Map<int, LogicalLetter> prefillPositions;

  int get currentAttempt => guesses.length;
  int get remainingAttempts => maxAttempts - guesses.length;
  bool get isTerminal => status == GameStatus.won || status == GameStatus.lost;
  bool get isInputFull => input.length == wordLength;

  /// Best-known keyboard state per letter (see [KeyboardAggregator]). The locked
  /// prefix letters are known-correct from the start, so the keyboard shows them
  /// green before the first guess (WS4).
  Map<LogicalLetter, LetterResult> get keyboardStates {
    final best = KeyboardAggregator.aggregate(guesses);
    for (final letter in lockedPrefix) {
      best[letter] = LetterResult.correct; // highest priority, never downgrades
    }
    return best;
  }

  /// Begins play from [GameStatus.idle].
  GameState start(List<LogicalLetter> newAnswer) {
    assert(status == GameStatus.idle, 'start() only valid from idle');
    return GameState.playing(
      answer: newAnswer,
      wordLength: wordLength,
      maxAttempts: maxAttempts,
      lockedPrefix: lockedPrefix,
    );
  }

  /// Appends a letter to the current row if there is space and play is active.
  /// Any position immediately following (locked or pre-filled) is auto-included
  /// too, so [input] always stays a contiguous prefix and its length always
  /// equals the next genuinely-empty column — the invariant [HintEngine] relies
  /// on when picking the next reveal-letter position.
  GameState addLetter(LogicalLetter letter) {
    if (status != GameStatus.playing || isInputFull) return this;
    final next = [...input, letter];
    var i = next.length;
    while (i < wordLength) {
      final carried = lockedPositions[i] ?? prefillPositions[i];
      if (carried == null) break;
      next.add(carried);
      i++;
    }
    return copyWith(input: next);
  }

  /// Removes the last user-editable staged letter — locked positions (WS4
  /// prefix or a carried-forward correct) are never removed; trailing locked
  /// positions after the removed letter are dropped along with it, since they
  /// are no longer contiguously resolved.
  GameState removeLetter() {
    if (status != GameStatus.playing) return this;
    var i = input.length;
    while (i > 0 && lockedPositions.containsKey(i - 1)) {
      i--;
    }
    if (i == 0) return this;
    return copyWith(input: input.sublist(0, i - 1));
  }

  /// Evaluates and commits the current row. Caller must ensure the row is full
  /// and the word is valid; a no-op otherwise. [lockedPositions] and
  /// [prefillPositions] carry over unchanged — the next row is re-staged with
  /// them exactly as before. Use [submitWithCarryForward] to also grow them
  /// from this guess's result (WS-carry-forward).
  GameState submit() => _submit(carryForward: false);

  /// Same as [submit], but also grows [lockedPositions] with any newly
  /// `correct` letter from this guess and replaces [prefillPositions] with this
  /// guess's `present` letters (skipping any position that is now locked), then
  /// re-stages the next row with both. Domain-only: scoring itself is untouched.
  GameState submitWithCarryForward() => _submit(carryForward: true);

  /// Commits externally-evaluated [results] instead of running the local
  /// [GuessEvaluator] — for modes (daily) whose scoring is authoritative
  /// server-side. Otherwise identical to [submitWithCarryForward]: grows
  /// [lockedPositions]/[prefillPositions] the same way. [revealedAnswer]
  /// optionally sets the real word once the server has revealed it (win or a
  /// granted final-attempt reveal); omitted/null leaves [answer] unchanged.
  GameState submitWithServerResults(
    List<LetterResult> results, {
    List<LogicalLetter>? revealedAnswer,
  }) {
    if (status != GameStatus.playing || !isInputFull) return this;
    final nextGuesses = [...guesses, Guess(letters: input, results: results)];
    final won = results.every((r) => r == LetterResult.correct);
    final lost = !won && nextGuesses.length >= maxAttempts;

    final locked = Map<int, LogicalLetter>.of(lockedPositions);
    final prefill = <int, LogicalLetter>{};
    for (var i = 0; i < results.length; i++) {
      if (results[i] == LetterResult.correct) {
        locked[i] = input[i];
      } else if (results[i] == LetterResult.present && !locked.containsKey(i)) {
        prefill[i] = input[i];
      }
    }

    return copyWith(
      answer: revealedAnswer ?? answer,
      guesses: nextGuesses,
      input: _seedInput(wordLength, locked, prefill),
      status: won
          ? GameStatus.won
          : lost
              ? GameStatus.lost
              : GameStatus.playing,
      lockedPositions: locked,
      prefillPositions: prefill,
    );
  }

  GameState _submit({required bool carryForward}) {
    if (status != GameStatus.playing || !isInputFull) return this;
    final results = GuessEvaluator.evaluate(input, answer);
    final nextGuesses = [
      ...guesses,
      Guess(letters: input, results: results),
    ];
    final won = results.every((r) => r == LetterResult.correct);
    final lost = !won && nextGuesses.length >= maxAttempts;

    var nextLocked = lockedPositions;
    var nextPrefill = prefillPositions;
    if (carryForward) {
      final locked = Map<int, LogicalLetter>.of(lockedPositions);
      final prefill = <int, LogicalLetter>{};
      for (var i = 0; i < results.length; i++) {
        if (results[i] == LetterResult.correct) {
          locked[i] = input[i];
        } else if (results[i] == LetterResult.present &&
            !locked.containsKey(i)) {
          prefill[i] = input[i];
        }
      }
      nextLocked = locked;
      nextPrefill = prefill;
    }

    return copyWith(
      guesses: nextGuesses,
      input: _seedInput(wordLength, nextLocked, nextPrefill),
      status: won
          ? GameStatus.won
          : lost
          ? GameStatus.lost
          : GameStatus.playing,
      lockedPositions: nextLocked,
      prefillPositions: nextPrefill,
    );
  }

  /// Builds the leading contiguous run of a fresh row: locked and pre-filled
  /// letters starting at column 0, stopping at the first genuinely-empty
  /// editable column (see [addLetter]/[removeLetter] for why this must stay
  /// contiguous).
  static List<LogicalLetter> _seedInput(
    int wordLength,
    Map<int, LogicalLetter> locked,
    Map<int, LogicalLetter> prefill,
  ) {
    final seeded = <LogicalLetter>[];
    for (var i = 0; i < wordLength; i++) {
      final letter = locked[i] ?? prefill[i];
      if (letter == null) break;
      seeded.add(letter);
    }
    return seeded;
  }

  GameState copyWith({
    List<LogicalLetter>? answer,
    List<Guess>? guesses,
    List<LogicalLetter>? input,
    GameStatus? status,
    int? wordLength,
    int? maxAttempts,
    List<LogicalLetter>? lockedPrefix,
    Map<int, LogicalLetter>? lockedPositions,
    Map<int, LogicalLetter>? prefillPositions,
  }) => GameState(
    answer: answer ?? this.answer,
    guesses: guesses ?? this.guesses,
    input: input ?? this.input,
    status: status ?? this.status,
    wordLength: wordLength ?? this.wordLength,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    lockedPrefix: lockedPrefix ?? this.lockedPrefix,
    lockedPositions: lockedPositions ?? this.lockedPositions,
    prefillPositions: prefillPositions ?? this.prefillPositions,
  );

  @override
  List<Object?> get props => [
    answer,
    guesses,
    input,
    status,
    wordLength,
    maxAttempts,
    lockedPrefix,
    lockedPositions,
    prefillPositions,
  ];
}
