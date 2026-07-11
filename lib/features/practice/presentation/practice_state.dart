import 'package:equatable/equatable.dart';

import '../../../core/config/game_config.dart';
import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';

enum PracticePhase { playing, solved, failed }

/// UI state of a practice round (Track A — reuses the daily board layout with a
/// solved/failed overlay instead of a full-screen recap).
class PracticeState extends Equatable {
  const PracticeState({
    required this.tier,
    this.phase = PracticePhase.playing,
    this.guesses = const [],
    this.keyStates = const {},
    this.answer = const [],
    this.answerDefinition,
    this.reward = 0,
    this.shakeSignal = 0,
    this.invalidWord = false,
    this.roundNonce = 0,
  });

  final PracticeTier tier;
  final PracticePhase phase;
  final List<Guess> guesses;
  final Map<LogicalLetter, LetterResult> keyStates;
  final List<LogicalLetter> answer;
  final String? answerDefinition;
  final int reward;
  final int shakeSignal;
  final bool invalidWord;

  /// Bumped whenever a new round begins so the screen resets its board.
  final int roundNonce;

  int get attemptsUsed => guesses.length;

  PracticeState copyWith({
    PracticeTier? tier,
    PracticePhase? phase,
    List<Guess>? guesses,
    Map<LogicalLetter, LetterResult>? keyStates,
    List<LogicalLetter>? answer,
    Object? answerDefinition = _keep,
    int? reward,
    int? shakeSignal,
    bool? invalidWord,
    int? roundNonce,
  }) => PracticeState(
    tier: tier ?? this.tier,
    phase: phase ?? this.phase,
    guesses: guesses ?? this.guesses,
    keyStates: keyStates ?? this.keyStates,
    answer: answer ?? this.answer,
    answerDefinition: answerDefinition == _keep
        ? this.answerDefinition
        : answerDefinition as String?,
    reward: reward ?? this.reward,
    shakeSignal: shakeSignal ?? this.shakeSignal,
    invalidWord: invalidWord ?? this.invalidWord,
    roundNonce: roundNonce ?? this.roundNonce,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    tier,
    phase,
    guesses,
    keyStates,
    answer,
    answerDefinition,
    reward,
    shakeSignal,
    invalidWord,
    roundNonce,
  ];
}
