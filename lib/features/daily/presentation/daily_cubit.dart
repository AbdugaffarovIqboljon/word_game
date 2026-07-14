import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/game_config.dart';
import '../../../core/game/domain/dictionary.dart';
import '../../../core/game/domain/game_state.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/word_tokenizer.dart';
import '../../../core/game/presentation/clean_hint_pulse.dart';
import '../../../core/time/game_clock.dart';
import '../../../features/stats/data/stats_repository.dart';
import '../../../features/streak/data/streak_history_repository.dart';
import '../../../features/streak/data/streak_repository.dart';
import '../../../features/streak/domain/streak_calculator.dart';
import '../../../features/wallet/data/wallet_service.dart';
import '../data/daily_board_repository.dart';
import '../data/daily_chest_repository.dart';
import '../domain/daily_board_snapshot.dart';
import '../domain/daily_puzzle_repository.dart';
import '../domain/daily_reward.dart';
import 'daily_state.dart';

/// Orchestrates the daily puzzle: loads today's metadata and any restored
/// board, stages typing, and submits guesses to the server-authoritative
/// `evaluate-guess` Edge Function (via [DailyPuzzleRepository]) — the client
/// never knows the answer during play, only what each guess's evaluation
/// reveals about it, plus a leading letter the backend explicitly reveals
/// (WS4). On terminal states it records the streak, stats, and coin reward
/// exactly once.
///
/// The staged typing row is exposed as [input] (a hot path) so keystrokes never
/// emit a new [DailyState] — only submissions, reveals and phase changes do.
class DailyCubit extends Cubit<DailyState> {
  DailyCubit({
    required Dictionary dictionary,
    required DailyPuzzleRepository puzzleRepo,
    required GameClock clock,
    required GameConfig config,
    required DailyBoardRepository boardRepo,
    required DailyChestRepository chestRepo,
    required StreakRepository streakRepo,
    required StreakHistoryRepository historyRepo,
    required StatsRepository statsRepo,
    required WalletService wallet,
  }) : _dictionary = dictionary,
       _puzzleRepo = puzzleRepo,
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
  final DailyPuzzleRepository _puzzleRepo;
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
  late List<LogicalLetter> _lockedPrefix = const [];
  int _puzzleNumber = 0;
  String? _theme;
  late DailyBoardSnapshot _snapshot;

  /// Re-entrancy guard: a submission is already in flight against the network.
  bool _isSubmitting = false;

  /// Keyboard hints applied this game (clean-keyboard), merged into key states.
  /// Always empty for daily — see [canCleanKeyboard].
  final Map<LogicalLetter, LetterResult> _hintOverrides = {};

  /// Fires when the clean-keyboard hint grays a batch, so the keyboard can play
  /// its staggered fade. Never emits a [DailyState] — it is a pure UI signal.
  final ValueNotifier<CleanHintPulse?> cleanPulse = ValueNotifier(null);

  int get currentRow => _game.guesses.length;
  int get maxAttempts => _config.maxAttempts;
  int get wordLength => _config.wordLength;
  DateTime get today => _today;

  /// Revealed/locked leading letters for the board to pre-fill (WS4). Now
  /// server-granted (`daily_puzzle_public.locked_prefix_raw`), not derived
  /// from a client-known answer.
  List<LogicalLetter> get lockedPrefix => _lockedPrefix;

  /// Board positions carried forward as locked/pre-filled from prior guesses —
  /// see [GameState.lockedPositions] / [GameState.prefillPositions].
  Map<int, LogicalLetter> get lockedPositions => _game.lockedPositions;
  Map<int, LogicalLetter> get prefillPositions => _game.prefillPositions;

  /// The Lugʻat (definition) hint has no server-side source yet — evaluation
  /// moving server-side means the client no longer holds the plaintext answer
  /// needed to look one up locally. Temporarily disabled for daily (practice
  /// is unaffected) pending a dedicated backend endpoint.
  bool get hasDefinition => false;
  String? get definition => null;

  Future<void> load() async {
    final today = _clock.puzzleDate();
    _today = today;
    emit(const DailyState()); // fresh loading spinner (retry / day rollover)

    final DailyPuzzleMeta meta;
    try {
      meta = await _puzzleRepo.fetchMeta(today);
    } catch (_) {
      emit(const DailyState(loadError: true));
      return;
    }

    _puzzleNumber = meta.puzzleNumber;
    _theme = meta.theme;
    _lockedPrefix = _resolveLockedPrefix(meta);

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

    // Replay any persisted board for today through the engine. Each stored
    // guess already carries its server-evaluated results (never recomputed
    // locally — daily's scoring is authoritative server-side).
    var game = GameState.playing(
      answer: const [],
      wordLength: _config.wordLength,
      maxAttempts: _config.maxAttempts,
      lockedPrefix: _lockedPrefix,
    );
    var snapshot = _boardRepo.loadFor(today);
    if (snapshot != null) {
      for (final guess in snapshot.guesses) {
        if (game.status != GameStatus.playing) break;
        game = game
            .copyWith(input: guess.letters)
            .submitWithServerResults(guess.results);
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

    // A restored, already-lost board never persisted the answer locally (it
    // must not be) — opportunistically re-fetch it for FailView; best-effort,
    // never blocks the board from showing.
    if (game.status == GameStatus.lost &&
        game.answer.isEmpty &&
        game.guesses.isNotEmpty) {
      unawaited(_refetchRevealedAnswer(today, game.guesses.last.letters));
    }

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

  List<LogicalLetter> _resolveLockedPrefix(DailyPuzzleMeta meta) {
    if (!_config.revealFirstLetter) return const [];
    final raw = meta.lockedPrefixRaw;
    if (raw == null || raw.isEmpty) return const [];
    final tokens = WordTokenizer.tokenize(raw);
    return tokens.isEmpty ? const [] : [tokens.first];
  }

  Future<void> _refetchRevealedAnswer(
    DateTime date,
    List<LogicalLetter> lastGuess,
  ) async {
    try {
      final evaluation = await _puzzleRepo.evaluateGuess(
        puzzleDate: date,
        guess: lastGuess.map((l) => l.value).join(),
        revealOnFail: true,
      );
      final answer = evaluation.answer;
      if (answer == null || isClosed) return;
      _game = _game.copyWith(answer: WordTokenizer.tokenize(answer));
      emit(_build(phase: state.phase));
    } catch (_) {
      // Best-effort only — FailView simply shows no answer if this fails.
    }
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
    if (_game.status != GameStatus.playing || _isSubmitting) return;
    final word = _game.input;
    if (word.length < _config.wordLength) {
      _bumpShake(invalid: false);
      return;
    }
    if (!_dictionary.contains(word)) {
      _bumpShake(invalid: true);
      return;
    }

    _isSubmitting = true;
    final isLastAttempt = _game.guesses.length == _config.maxAttempts - 1;

    final GuessEvaluation evaluation;
    try {
      evaluation = await _puzzleRepo.evaluateGuess(
        puzzleDate: _today,
        guess: word.map((l) => l.value).join(),
        revealOnFail: isLastAttempt,
      );
    } on InvalidGuessWordException {
      _isSubmitting = false;
      _bumpShake(invalid: true);
      return;
    } on DailyPuzzleUnavailableException {
      _isSubmitting = false;
      if (!isClosed) {
        emit(state.copyWith(networkErrorSignal: state.networkErrorSignal + 1));
      }
      return;
    }
    _isSubmitting = false;
    if (isClosed) return;

    final revealedAnswer = evaluation.answer != null
        ? WordTokenizer.tokenize(evaluation.answer!)
        : null;
    _game = _game.submitWithServerResults(
      evaluation.results,
      revealedAnswer: revealedAnswer,
    );
    input.value = _game.input; // now empty
    _snapshot = _snapshot.copyWith(guesses: _game.guesses);
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

  /// Reveal-letter hint: temporarily disabled for daily. Server-side
  /// evaluation means the client no longer holds the answer during play, so
  /// this can't be computed locally anymore — see [hasDefinition] for the
  /// same reasoning. A no-op until a dedicated hint endpoint exists.
  void revealLetter() {}

  /// Clean-keyboard hint: temporarily disabled for daily for the same reason
  /// as [revealLetter] — always unavailable until a dedicated hint endpoint
  /// exists.
  bool get canCleanKeyboard => false;

  Future<bool> purchaseCleanKeyboard({
    required Future<bool> Function() pay,
    required Future<void> Function() refund,
  }) async => false;

  Future<bool> purchaseDefinition({
    required Future<bool> Function() pay,
    required Future<void> Function() refund,
    required Future<bool> Function(String definition) reveal,
  }) async => false;

  List<LogicalLetter> cleanKeyboard() => const [];

  /// Charges coins to recall the already-known theme-hint banner. Unlike a
  /// gated hint, the effect (showing [DailyState.theme]) can never fail once
  /// bought, so this is a plain atomic debit — no pay/refund dance needed.
  Future<bool> purchaseThemeRecall() async {
    if (_theme == null || _theme!.isEmpty) return false;
    return _wallet.debitCoins(
      _config.hintThemeRecallPrice,
      reason: 'daily_theme_recall',
    );
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
    answer: _game.answer,
    answerDefinition: null,
    reward: reward ?? (phase == DailyPhase.solved ? state.reward : null),
    chestUnclaimed: chestUnclaimed ?? state.chestUnclaimed,
    shakeSignal: state.shakeSignal,
    theme: _theme,
  );

  @override
  Future<void> close() {
    input.dispose();
    cleanPulse.dispose();
    return super.close();
  }
}
