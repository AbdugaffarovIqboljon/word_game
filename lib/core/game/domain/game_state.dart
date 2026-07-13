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
  });

  /// Pre-load state: no answer, nothing playable.
  const GameState.idle({this.wordLength = 5, this.maxAttempts = 5})
    : answer = const [],
      guesses = const [],
      input = const [],
      status = GameStatus.idle,
      lockedPrefix = const [];

  /// A fresh, playable puzzle for [answer].
  ///
  /// [lockedPrefix] (WS4) are leading letters that are revealed and locked from
  /// the start: the row is pre-staged with them, they cannot be deleted, and they
  /// count as submitted-correct. With `reveal_first_letter` on this is
  /// `[answer.first]`, so every row begins on the answer's green first letter.
  factory GameState.playing({
    required List<LogicalLetter> answer,
    int wordLength = 5,
    int maxAttempts = 5,
    List<LogicalLetter> lockedPrefix = const [],
  }) => GameState(
    answer: answer,
    guesses: const [],
    input: List<LogicalLetter>.of(lockedPrefix),
    status: GameStatus.playing,
    wordLength: wordLength,
    maxAttempts: maxAttempts,
    lockedPrefix: lockedPrefix,
  );

  final List<LogicalLetter> answer;
  final List<Guess> guesses;
  final List<LogicalLetter> input; // current, unsubmitted row (starts on lockedPrefix)
  final GameStatus status;
  final int wordLength;
  final int maxAttempts;

  /// Revealed, locked leading letters (WS4). Empty when the reveal is off.
  final List<LogicalLetter> lockedPrefix;

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
  GameState addLetter(LogicalLetter letter) {
    if (status != GameStatus.playing || isInputFull) return this;
    return copyWith(input: [...input, letter]);
  }

  /// Removes the last staged letter, but never the locked prefix (WS4).
  GameState removeLetter() {
    if (status != GameStatus.playing || input.length <= lockedPrefix.length) {
      return this;
    }
    return copyWith(input: input.sublist(0, input.length - 1));
  }

  /// Evaluates and commits the current row. Caller must ensure the row is full
  /// and the word is valid; a no-op otherwise.
  GameState submit() {
    if (status != GameStatus.playing || !isInputFull) return this;
    final results = GuessEvaluator.evaluate(input, answer);
    final nextGuesses = [
      ...guesses,
      Guess(letters: input, results: results),
    ];
    final won = results.every((r) => r == LetterResult.correct);
    final lost = !won && nextGuesses.length >= maxAttempts;
    return copyWith(
      guesses: nextGuesses,
      input: List<LogicalLetter>.of(lockedPrefix), // next row re-stages the prefix
      status: won
          ? GameStatus.won
          : lost
          ? GameStatus.lost
          : GameStatus.playing,
    );
  }

  GameState copyWith({
    List<LogicalLetter>? answer,
    List<Guess>? guesses,
    List<LogicalLetter>? input,
    GameStatus? status,
    int? wordLength,
    int? maxAttempts,
    List<LogicalLetter>? lockedPrefix,
  }) => GameState(
    answer: answer ?? this.answer,
    guesses: guesses ?? this.guesses,
    input: input ?? this.input,
    status: status ?? this.status,
    wordLength: wordLength ?? this.wordLength,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    lockedPrefix: lockedPrefix ?? this.lockedPrefix,
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
  ];
}
