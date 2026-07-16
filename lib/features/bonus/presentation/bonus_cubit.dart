import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/game_config.dart';
import '../../../core/game/domain/dictionary.dart';
import '../../../core/game/domain/game_state.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/word_tokenizer.dart';
import '../../../core/game/presentation/clean_hint_pulse.dart';
import '../../../core/time/game_clock.dart';
import '../../hints/domain/hint_engine.dart';
import '../../stats/data/stats_repository.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/bonus_played_repository.dart';
import 'bonus_state.dart';

/// Supplies the full answer pool (all difficulties combined) for bonus words.
typedef BonusAnswers = List<List<LogicalLetter>> Function();

/// Drives a bonus ("Yana yechish") round (WS3). Reuses the game engine + hint
/// engine, but is deliberately isolated from the daily flow: it grants coins and
/// tallies bonus-only stats, and NEVER touches the streak, the daily share grid
/// or the daily countdown. Played words are persisted so none reappears.
class BonusCubit extends Cubit<BonusState> {
  BonusCubit({
    required Dictionary dictionary,
    required BonusAnswers pool,
    required GameConfig config,
    required WalletService wallet,
    required StatsRepository statsRepo,
    required BonusPlayedRepository playedRepo,
    required GameClock clock,
    Random? random,
    AnalyticsService analytics = const NoopAnalyticsService(),
  }) : _dictionary = dictionary,
       _pool = pool,
       _config = config,
       _wallet = wallet,
       _statsRepo = statsRepo,
       _playedRepo = playedRepo,
       _clock = clock,
       _random = random ?? Random(),
       _analytics = analytics,
       super(const BonusState());

  final Dictionary _dictionary;
  final BonusAnswers _pool;
  final GameConfig _config;
  final WalletService _wallet;
  final StatsRepository _statsRepo;
  final BonusPlayedRepository _playedRepo;
  final GameClock _clock;
  final Random _random;
  final AnalyticsService _analytics;

  static const Duration revealDuration = Duration(milliseconds: 700);

  final ValueNotifier<List<LogicalLetter>> input = ValueNotifier(const []);
  final ValueNotifier<CleanHintPulse?> cleanPulse = ValueNotifier(null);
  final Map<LogicalLetter, LetterResult> _hintOverrides = {};

  late GameState _game;
  late List<LogicalLetter> _answer;
  late List<LogicalLetter> _lockedPrefix = const [];
  String? _definition;

  int get currentRow => _game.guesses.length;
  int get maxAttempts => _config.maxAttempts;
  int get wordLength => _config.wordLength;
  String? get definition => _definition;
  bool get hasDefinition => _definition != null && _definition!.isNotEmpty;
  List<LogicalLetter> get lockedPrefix => _lockedPrefix;

  /// Begins a fresh bonus word: a random answer from the full pool that the user
  /// has not already played. Emits [BonusPhase.empty] when the pool is exhausted.
  void start() {
    _hintOverrides.clear();
    input.value = const [];

    final played = _playedRepo.load();
    final available = _pool()
        .where((w) => !played.contains(WordTokenizer.keyOf(w)))
        .toList();
    if (available.isEmpty) {
      _answer = const [];
      emit(state.copyWith(
        phase: BonusPhase.empty,
        guesses: const [],
        keyStates: const {},
        answer: const [],
        answerDefinition: null,
        roundNonce: state.roundNonce + 1,
      ));
      return;
    }

    _answer = available[_random.nextInt(available.length)];
    _definition = _dictionary.definitionFor(_answer);
    _lockedPrefix = _config.revealFirstLetter && _answer.isNotEmpty
        ? [_answer.first]
        : const [];
    _game = GameState.playing(
      answer: _answer,
      wordLength: _config.wordLength,
      maxAttempts: _config.maxAttempts,
      lockedPrefix: _lockedPrefix,
    );
    input.value = _game.input;

    emit(state.copyWith(
      phase: BonusPhase.playing,
      guesses: const [],
      keyStates: const {},
      answer: _answer,
      answerDefinition: _definition,
      reward: 0,
      roundNonce: state.roundNonce + 1,
    ));
  }

  void addLetter(LogicalLetter letter) {
    final next = _game.addLetter(letter);
    if (identical(next, _game)) return;
    _game = next;
    input.value = _game.input;
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
      _analytics.wordRejected(
        word: word.map((l) => l.value).join(),
        mode: 'bonus',
        date: _clock.puzzleDate().toIso8601String(),
      );
      _bumpShake(invalid: true);
      return;
    }

    _game = _game.submit();
    input.value = _game.input;
    emit(_build(phase: BonusPhase.playing));

    if (_game.isTerminal) {
      await Future.delayed(revealDuration);
      if (isClosed) return;
      await _applyOutcome();
    }
  }

  /// Records the outcome into the bonus counters only — the streak, daily share
  /// and countdown are never touched (WS3). The word is marked played either way.
  Future<void> _applyOutcome() async {
    await _playedRepo.add(WordTokenizer.keyOf(_answer));
    final stats = _statsRepo.load();
    if (_game.status == GameStatus.won) {
      final reward = _config.bonusWordReward;
      await _wallet.creditCoins(reward, reason: 'bonus_word');
      await _statsRepo.save(stats.recordBonusWin());
      emit(_build(phase: BonusPhase.solved, reward: reward));
    } else {
      await _statsRepo.save(stats.recordBonusLoss());
      emit(_build(phase: BonusPhase.failed));
    }
  }

  void revealLetter() {
    final letter = HintEngine.nextCorrectLetter(_game);
    if (letter == null) return;
    addLetter(letter);
  }

  Set<LogicalLetter> get _knownLetters =>
      {..._game.keyboardStates.keys, ..._hintOverrides.keys};

  bool get canCleanKeyboard =>
      _game.status == GameStatus.playing &&
      HintEngine.absentCandidates(_answer, _knownLetters).isNotEmpty;

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

  List<LogicalLetter> cleanKeyboard() {
    final picked = HintEngine.pickAbsentLetters(
      _answer,
      _knownLetters,
      count: _config.hintCleanCount,
      random: _random,
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

  void _bumpShake({required bool invalid}) {
    emit(state.copyWith(shakeSignal: state.shakeSignal + 1, invalidWord: invalid));
  }

  BonusState _build({required BonusPhase phase, int? reward}) => state.copyWith(
    phase: phase,
    guesses: _game.guesses,
    keyStates: _mergedKeyStates(),
    answer: _answer,
    answerDefinition: _definition,
    reward: reward,
  );

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

  @override
  Future<void> close() {
    input.dispose();
    cleanPulse.dispose();
    return super.close();
  }
}
