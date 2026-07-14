import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/game_config.dart';
import '../../../core/game/domain/dictionary.dart';
import '../../../core/game/domain/game_state.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/presentation/clean_hint_pulse.dart';
import '../../../core/time/game_clock.dart';
import '../../hints/domain/hint_engine.dart';
import '../../../features/stats/data/stats_repository.dart';
import '../../../features/streak/data/streak_history_repository.dart';
import '../../../features/streak/data/streak_repository.dart';
import '../../../features/streak/domain/streak_calculator.dart';
import '../../../features/wallet/data/wallet_service.dart';
import '../data/daily_board_repository.dart';
import '../data/daily_chest_repository.dart';
import '../domain/daily_board_snapshot.dart';
import '../domain/daily_reward.dart';
import 'daily_state.dart';

/// Orchestrates the daily puzzle: loads/restores the board, applies typing,
/// validates & reveals submissions, and on terminal states records the streak,
/// stats, and coin reward exactly once.
///
/// The staged typing row is exposed as [input] (a hot path) so keystrokes never
/// emit a new [DailyState] — only submissions, reveals and phase changes do.
class DailyCubit extends Cubit<DailyState> {
  DailyCubit({
    required Dictionary dictionary,
    required GameClock clock,
    required GameConfig config,
    required DailyBoardRepository boardRepo,
    required DailyChestRepository chestRepo,
    required StreakRepository streakRepo,
    required StreakHistoryRepository historyRepo,
    required StatsRepository statsRepo,
    required WalletService wallet,
  }) : _dictionary = dictionary,
       _clock = clock,
       _config = config,
       _boardRepo = boardRepo,
       _chestRepo = chestRepo,
       _streakRepo = streakRepo,
       _historyRepo = historyRepo,
       _statsRepo = statsRepo,
       _wallet = wallet,
       super(const DailyState());

  final Dictionary _dictionary;
  final GameClock _clock;
  final GameConfig _config;
  final DailyBoardRepository _boardRepo;
  final DailyChestRepository _chestRepo;
  final StreakRepository _streakRepo;
  final StreakHistoryRepository _historyRepo;
  final StatsRepository _statsRepo;
  final WalletService _wallet;

  /// Staged, unsubmitted letters of the current row.
  final ValueNotifier<List<LogicalLetter>> input = ValueNotifier(const []);

  /// Total time for a full row reveal (5 tiles × 100ms stagger + 150ms flip).
  static const Duration revealDuration = Duration(milliseconds: 700);

  late GameState _game;
  late DateTime _today;
  late List<LogicalLetter> _answer;
  late List<LogicalLetter> _lockedPrefix = const [];
  late int _puzzleNumber;
  String? _definition;
  late DailyBoardSnapshot _snapshot;

  /// Keyboard hints applied this game (clean-keyboard), merged into key states.
  final Map<LogicalLetter, LetterResult> _hintOverrides = {};

  /// Fires when the clean-keyboard hint grays a batch, so the keyboard can play
  /// its staggered fade. Never emits a [DailyState] — it is a pure UI signal.
  final ValueNotifier<CleanHintPulse?> cleanPulse = ValueNotifier(null);

  int get currentRow => _game.guesses.length;
  int get maxAttempts => _config.maxAttempts;
  int get wordLength => _config.wordLength;
  String? get definition => _definition;
  DateTime get today => _today;

  /// Revealed/locked leading letters for the board to pre-fill (WS4).
  List<LogicalLetter> get lockedPrefix => _lockedPrefix;

  /// Board positions carried forward as locked/pre-filled from prior guesses —
  /// see [GameState.lockedPositions] / [GameState.prefillPositions].
  Map<int, LogicalLetter> get lockedPositions => _game.lockedPositions;
  Map<int, LogicalLetter> get prefillPositions => _game.prefillPositions;

  /// Whether a Lugʻat (dictionary) definition exists for today's word. The hint
  /// card is shown only when this is true (WS1 req b).
  bool get hasDefinition => _definition != null && _definition!.isNotEmpty;

  Future<void> load() async {
    final today = _clock.puzzleDate();
    _today = today;
    _answer = _dictionary.answerForDate(today);
    _puzzleNumber = _dictionary.puzzleNumberForDate(today);
    _definition = _dictionary.definitionFor(_answer);

    // Reconcile any missed days (consume freezes / break), idempotently.
    var streak = _streakRepo.load();
    final priorAnchor = streak.anchorDate;
    final reconcile = StreakCalculator.reconcile(streak, today);
    if (reconcile.outcome != StreakOutcome.none) {
      streak = reconcile.data;
      await _streakRepo.save(streak);
      await _streakRepo.setPendingOutcome(reconcile.outcome);
      if (reconcile.outcome == StreakOutcome.savedByFreeze &&
          priorAnchor != null) {
        final frozen = <DateTime>[];
        for (var d = priorAnchor.add(const Duration(days: 1));
            d.isBefore(today);
            d = d.add(const Duration(days: 1))) {
          frozen.add(DateTime.utc(d.year, d.month, d.day));
        }
        await _historyRepo.markFrozen(frozen);
      }
    }

    // WS4: reveal + lock the answer's first letter (config-driven).
    _lockedPrefix = _config.revealFirstLetter && _answer.isNotEmpty
        ? [_answer.first]
        : const [];

    // Replay any persisted board for today through the engine. Each stored word
    // is re-evaluated as a whole (robust to legacy boards saved before the
    // first-letter lock existed).
    var game = GameState.playing(
      answer: _answer,
      wordLength: _config.wordLength,
      maxAttempts: _config.maxAttempts,
      lockedPrefix: _lockedPrefix,
    );
    var snapshot = _boardRepo.loadFor(today);
    if (snapshot != null) {
      for (final word in snapshot.guesses) {
        if (game.status != GameStatus.playing) break;
        game = game.copyWith(input: word).submitWithCarryForward();
      }
    } else {
      snapshot = DailyBoardSnapshot(
        puzzleDate: today,
        guesses: const [],
        outcomeRecorded: false,
      );
    }
    _game = game;
    input.value = _game.input; // stage the locked prefix for the active row

    DailyReward? reward;
    if (game.isTerminal && !snapshot.outcomeRecorded) {
      reward = await _applyOutcome(today, game);
      snapshot = snapshot.copyWith(outcomeRecorded: true);
      await _boardRepo.save(snapshot);
      streak = _streakRepo.load();
    } else if (game.status == GameStatus.won) {
      reward = DailyReward.forSolve(
        _config,
        attemptsUsed: game.guesses.length,
        streakAfter: streak.current,
      );
    }
    _snapshot = snapshot;

    emit(
      _build(
        phase: _phaseFor(game.status),
        reward: reward,
        streak: streak.current,
        chestUnclaimed: _chestRepo.isReady(today),
      ),
    );
  }

  void addLetter(LogicalLetter letter) {
    final next = _game.addLetter(letter);
    if (identical(next, _game)) return;
    _game = next;
    input.value = _game.input; // mirror for the board (no state emit)
  }

  void removeLetter() {
    final next = _game.removeLetter();
    if (identical(next, _game)) return;
    _game = next;
    input.value = _game.input;
  }

  Future<void> submit() async {
    if (_game.status != GameStatus.playing) return;
    final word = _game.input;
    if (word.length < _config.wordLength) {
      _bumpShake(invalid: false);
      return;
    }
    if (!_dictionary.contains(word)) {
      _bumpShake(invalid: true);
      return;
    }

    _game = _game.submitWithCarryForward();
    input.value = _game.input; // now empty
    _snapshot = _snapshot.copyWith(
      guesses: _game.guesses.map((g) => g.letters).toList(),
    );
    await _boardRepo.save(_snapshot);

    // First emit keeps phase=playing so the submitted row flips before the
    // solved/failed layout replaces the board.
    emit(_build(phase: DailyPhase.playing));

    if (_game.isTerminal) {
      await Future.delayed(revealDuration);
      if (isClosed) return;
      final reward = await _applyOutcome(_today, _game);
      _snapshot = _snapshot.copyWith(outcomeRecorded: true);
      await _boardRepo.save(_snapshot);
      emit(
        _build(
          phase: _phaseFor(_game.status),
          reward: reward,
          streak: _streakRepo.load().current,
        ),
      );
    }
  }

  /// Reveal-letter hint: auto-types the correct letter for the next slot.
  void revealLetter() {
    final letter = HintEngine.nextCorrectLetter(_game);
    if (letter == null) return;
    addLetter(letter);
  }

  /// The letters already known (revealed on the keyboard by a submitted guess or
  /// grayed by a prior clean hint) — excluded from clean-hint selection.
  Set<LogicalLetter> get _knownLetters => {
    ..._game.keyboardStates.keys,
    ..._hintOverrides.keys,
  };

  /// Whether the clean-keyboard hint can gray at least one new letter. When
  /// false the hint must be shown disabled and must never charge (req b).
  bool get canCleanKeyboard =>
      _game.status == GameStatus.playing &&
      HintEngine.absentCandidates(_answer, _knownLetters).isNotEmpty;

  /// Atomically buys the clean-keyboard hint: gates on availability, charges via
  /// [pay] only when an effect will occur, and refunds via [refund] on any
  /// failure so a charge never lands without a visible effect (req b/c).
  Future<bool> purchaseCleanKeyboard({
    required Future<bool> Function() pay,
    required Future<void> Function() refund,
  }) async {
    if (!canCleanKeyboard) return false;
    if (!await pay()) return false;
    final applied = cleanKeyboard();
    if (applied.isEmpty) {
      await refund();
      return false;
    }
    return true;
  }

  /// Atomically buys the Lugʻat (definition) hint: gates on a definition being
  /// available, charges via [pay] only then, displays it via [reveal], and
  /// refunds via [refund] if the display fails — so a charge never lands without
  /// the definition actually being shown (WS1 req c). [reveal] returns whether
  /// the definition was displayed.
  Future<bool> purchaseDefinition({
    required Future<bool> Function() pay,
    required Future<void> Function() refund,
    required Future<bool> Function(String definition) reveal,
  }) async {
    final def = _definition;
    if (def == null || def.isEmpty) return false;
    if (!await pay()) return false;
    final shown = await reveal(def);
    if (!shown) {
      await refund();
      return false;
    }
    return true;
  }

  /// Clean-keyboard hint: grays out up to [GameConfig.hintCleanCount] genuinely-
  /// absent letters (however many qualify, min 1). Returns the letters actually
  /// grayed — empty when none qualify, so the caller can avoid charging.
  List<LogicalLetter> cleanKeyboard() {
    final picked = HintEngine.pickAbsentLetters(
      _answer,
      _knownLetters,
      count: _config.hintCleanCount,
      random: Random(),
    );
    if (picked.isEmpty) return const [];
    for (final letter in picked) {
      _hintOverrides[letter] = LetterResult.absent;
    }
    emit(_build(phase: state.phase));
    cleanPulse.value = CleanHintPulse(
      letters: picked,
      nonce: (cleanPulse.value?.nonce ?? 0) + 1,
    );
    return picked;
  }

  /// Refreshes the chest "unclaimed" dot after the chest dialog closes (the
  /// dialog itself credits coins and marks the chest claimed).
  void refreshChestFlag() {
    emit(_build(phase: state.phase, chestUnclaimed: _chestRepo.isReady(_today)));
  }

  Future<DailyReward?> _applyOutcome(DateTime today, GameState game) async {
    var streak = _streakRepo.load();
    final stats = _statsRepo.load();
    if (game.status == GameStatus.won) {
      streak = StreakCalculator.recordSolved(streak, today);
      await _streakRepo.save(streak);
      await _historyRepo.markSolved(today);
      await _statsRepo.save(stats.recordWin(game.guesses.length));
      final reward = DailyReward.forSolve(
        _config,
        attemptsUsed: game.guesses.length,
        streakAfter: streak.current,
      );
      await _wallet.creditCoins(reward.total, reason: 'daily_win');
      return reward;
    }
    streak = StreakCalculator.recordFail(streak, today);
    await _streakRepo.save(streak);
    await _statsRepo.save(stats.recordLoss());
    return null;
  }

  void _bumpShake({required bool invalid}) {
    emit(state.copyWith(shakeSignal: state.shakeSignal + 1, invalidWord: invalid));
  }

  Map<LogicalLetter, LetterResult> _mergedKeyStates() {
    final merged = Map<LogicalLetter, LetterResult>.of(_game.keyboardStates);
    _hintOverrides.forEach((letter, result) {
      final existing = merged[letter];
      if (existing == null || result.priority > existing.priority) {
        merged[letter] = result;
      }
    });
    return merged;
  }

  DailyPhase _phaseFor(GameStatus status) => switch (status) {
    GameStatus.won => DailyPhase.solved,
    GameStatus.lost => DailyPhase.failed,
    _ => DailyPhase.playing,
  };

  DailyState _build({
    required DailyPhase phase,
    DailyReward? reward,
    int? streak,
    bool? chestUnclaimed,
  }) => DailyState(
    phase: phase,
    guesses: _game.guesses,
    keyStates: _mergedKeyStates(),
    streak: streak ?? state.streak,
    puzzleNumber: _puzzleNumber,
    answer: _answer,
    answerDefinition: _definition,
    reward: reward ?? (phase == DailyPhase.solved ? state.reward : null),
    chestUnclaimed: chestUnclaimed ?? state.chestUnclaimed,
    shakeSignal: state.shakeSignal,
  );

  @override
  Future<void> close() {
    input.dispose();
    cleanPulse.dispose();
    return super.close();
  }
}
