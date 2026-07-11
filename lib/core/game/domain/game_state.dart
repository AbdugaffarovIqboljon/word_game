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
  });

  /// Pre-load state: no answer, nothing playable.
  const GameState.idle({this.wordLength = 5, this.maxAttempts = 6})
    : answer = const [],
      guesses = const [],
      input = const [],
      status = GameStatus.idle;

  /// A fresh, playable puzzle for [answer].
  factory GameState.playing({
    required List<LogicalLetter> answer,
    int wordLength = 5,
    int maxAttempts = 6,
  }) => GameState(
    answer: answer,
    guesses: const [],
    input: const [],
    status: GameStatus.playing,
    wordLength: wordLength,
    maxAttempts: maxAttempts,
  );

  final List<LogicalLetter> answer;
  final List<Guess> guesses;
  final List<LogicalLetter> input; // current, unsubmitted row
  final GameStatus status;
  final int wordLength;
  final int maxAttempts;

  int get currentAttempt => guesses.length;
  int get remainingAttempts => maxAttempts - guesses.length;
  bool get isTerminal => status == GameStatus.won || status == GameStatus.lost;
  bool get isInputFull => input.length == wordLength;

  /// Best-known keyboard state per letter (see [KeyboardAggregator]).
  Map<LogicalLetter, LetterResult> get keyboardStates =>
      KeyboardAggregator.aggregate(guesses);

  /// Begins play from [GameStatus.idle].
  GameState start(List<LogicalLetter> newAnswer) {
    assert(status == GameStatus.idle, 'start() only valid from idle');
    return GameState.playing(
      answer: newAnswer,
      wordLength: wordLength,
      maxAttempts: maxAttempts,
    );
  }

  /// Appends a letter to the current row if there is space and play is active.
  GameState addLetter(LogicalLetter letter) {
    if (status != GameStatus.playing || isInputFull) return this;
    return copyWith(input: [...input, letter]);
  }

  /// Removes the last staged letter.
  GameState removeLetter() {
    if (status != GameStatus.playing || input.isEmpty) return this;
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
      input: const [],
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
  }) => GameState(
    answer: answer ?? this.answer,
    guesses: guesses ?? this.guesses,
    input: input ?? this.input,
    status: status ?? this.status,
    wordLength: wordLength ?? this.wordLength,
    maxAttempts: maxAttempts ?? this.maxAttempts,
  );

  @override
  List<Object?> get props => [
    answer,
    guesses,
    input,
    status,
    wordLength,
    maxAttempts,
  ];
}
