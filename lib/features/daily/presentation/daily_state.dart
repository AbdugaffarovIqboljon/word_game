import 'package:equatable/equatable.dart';

import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../domain/daily_reward.dart';

enum DailyPhase { loading, playing, solved, failed }

/// UI-facing state of the daily board. Excludes the staged typing row and coin
/// balances — those are hot paths driven by dedicated [ValueListenable]s (the
/// input notifier on the cubit and the wallet balances) so typing/reward never
/// rebuilds the whole screen.
class DailyState extends Equatable {
  const DailyState({
    this.phase = DailyPhase.loading,
    this.guesses = const [],
    this.keyStates = const {},
    this.streak = 0,
    this.puzzleNumber = 0,
    this.answer = const [],
    this.answerDefinition,
    this.reward,
    this.chestUnclaimed = false,
    this.shakeSignal = 0,
    this.invalidWord = false,
  });

  final DailyPhase phase;
  final List<Guess> guesses;
  final Map<LogicalLetter, LetterResult> keyStates;
  final int streak;
  final int puzzleNumber;
  final List<LogicalLetter> answer;
  final String? answerDefinition;
  final DailyReward? reward;
  final bool chestUnclaimed;

  /// Bumped to trigger a single row shake (invalid/short word).
  final int shakeSignal;

  /// Whether the current shake should also surface the "not in dictionary" toast.
  final bool invalidWord;

  int get attemptsUsed => guesses.length;
  bool get isTerminal =>
      phase == DailyPhase.solved || phase == DailyPhase.failed;

  DailyState copyWith({
    DailyPhase? phase,
    List<Guess>? guesses,
    Map<LogicalLetter, LetterResult>? keyStates,
    int? streak,
    int? puzzleNumber,
    List<LogicalLetter>? answer,
    Object? answerDefinition = _keep,
    Object? reward = _keep,
    bool? chestUnclaimed,
    int? shakeSignal,
    bool? invalidWord,
  }) => DailyState(
    phase: phase ?? this.phase,
    guesses: guesses ?? this.guesses,
    keyStates: keyStates ?? this.keyStates,
    streak: streak ?? this.streak,
    puzzleNumber: puzzleNumber ?? this.puzzleNumber,
    answer: answer ?? this.answer,
    answerDefinition: answerDefinition == _keep
        ? this.answerDefinition
        : answerDefinition as String?,
    reward: reward == _keep ? this.reward : reward as DailyReward?,
    chestUnclaimed: chestUnclaimed ?? this.chestUnclaimed,
    shakeSignal: shakeSignal ?? this.shakeSignal,
    invalidWord: invalidWord ?? this.invalidWord,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    phase,
    guesses,
    keyStates,
    streak,
    puzzleNumber,
    answer,
    answerDefinition,
    reward,
    chestUnclaimed,
    shakeSignal,
    invalidWord,
  ];
}
