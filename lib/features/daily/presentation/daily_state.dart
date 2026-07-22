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
    this.loadError = false,
    this.networkErrorSignal = 0,
    this.theme,
    this.celebrateSignal = 0,
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

  /// True when [phase] is [DailyPhase.loading] because fetching today's puzzle
  /// metadata from the backend failed (offline/5xx) — distinct from the
  /// ordinary momentary loading spinner; the screen shows a retry action.
  final bool loadError;

  /// Bumped whenever a guess submission couldn't reach the backend — the UI
  /// surfaces a retry-friendly toast without shaking the row or clearing input.
  final int networkErrorSignal;

  /// Today's puzzle theme/category clue, or null when the puzzle has none.
  final String? theme;

  /// One-shot celebration signal (WS5): bumped exactly once by the cubit when a
  /// *fresh* win is committed, and never on a restored/already-solved board. The
  /// UI fires the confetti/bounce choreography on each change, so the trigger is
  /// an explicit state-machine event rather than something the widget infers
  /// from a phase transition (which a rebuild could swallow).
  final int celebrateSignal;

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
    bool? loadError,
    int? networkErrorSignal,
    Object? theme = _keep,
    int? celebrateSignal,
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
    loadError: loadError ?? this.loadError,
    networkErrorSignal: networkErrorSignal ?? this.networkErrorSignal,
    theme: theme == _keep ? this.theme : theme as String?,
    celebrateSignal: celebrateSignal ?? this.celebrateSignal,
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
    loadError,
    networkErrorSignal,
    theme,
    celebrateSignal,
  ];
}
