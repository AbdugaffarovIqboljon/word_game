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
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_engine.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/practice_repository.dart';
import '../domain/practice_session.dart';
import 'practice_state.dart';

/// Provides the answer pool for a difficulty tier (implemented by the production
/// dictionary; faked in tests).
typedef AnswersForTier = List<List<LogicalLetter>> Function(PracticeTier tier);

/// Drives a practice round: reuses the game engine, rewards coins per tier, and
/// shows a full-screen interstitial every Nth solve (free users).
class PracticeCubit extends Cubit<PracticeState> {
  PracticeCubit({
    required PracticeTier tier,
    required Dictionary dictionary,
    required AnswersForTier answersForTier,
    required GameConfig config,
    required WalletService wallet,
    required RewardGateway rewardGateway,
    required GameClock clock,
    required PracticeRepository repository,
    bool removeAds = false,
    Random? random,
  }) : _dictionary = dictionary,
       _answersForTier = answersForTier,
       _config = config,
       _wallet = wallet,
       _rewardGateway = rewardGateway,
       _clock = clock,
       _repository = repository,
       _removeAds = removeAds,
       _random = random ?? Random(),
       super(PracticeState(tier: tier));

  final Dictionary _dictionary;
  final AnswersForTier _answersForTier;
  final GameConfig _config;
  final WalletService _wallet;
  final RewardGateway _rewardGateway;
  final GameClock _clock;
  final PracticeRepository _repository;
  final bool _removeAds;
  final Random _random;

  static const Duration revealDuration = Duration(milliseconds: 700);

  final ValueNotifier<List<LogicalLetter>> input = ValueNotifier(const []);
  final Map<LogicalLetter, LetterResult> _hintOverrides = {};

  /// Fires when the clean-keyboard hint grays a batch (staggered fade signal).
  final ValueNotifier<CleanHintPulse?> cleanPulse = ValueNotifier(null);

  late GameState _game;
  late List<LogicalLetter> _answer;
  late List<LogicalLetter> _lockedPrefix = const [];
  String? _definition;
  late PracticeTier _tier;
  late PracticeSession _session;

  int get currentRow => _game.guesses.length;
  int get maxAttempts => _config.maxAttempts;
  int get wordLength => _config.wordLength;
  String? get definition => _definition;

  /// Revealed/locked leading letters for the board to pre-fill (WS4).
  List<LogicalLetter> get lockedPrefix => _lockedPrefix;

  /// Whether a Lugʻat definition exists for the current practice word. The hint
  /// card is shown only when this is true (WS1 req b) — most practice words have
  /// none, so it stays hidden in practice unless the word happens to have one.
  bool get hasDefinition => _definition != null && _definition!.isNotEmpty;

  /// 1-based round number within today's session (context header).
  int get sessionRound => _session.played + 1;

  /// Begins a new round for [tier].
  void start(PracticeTier tier) {
    _tier = tier;
    _session = _repository.loadFor(_clock.puzzleDate());
    _hintOverrides.clear();
    input.value = const [];

    final pool = _answersForTier(tier);
    _answer = pool.isEmpty
        ? const []
        : pool[_random.nextInt(pool.length)];
    _definition = _dictionary.definitionFor(_answer);
    // WS4: reveal + lock the answer's first letter (config-driven).
    _lockedPrefix = _config.revealFirstLetter && _answer.isNotEmpty
        ? [_answer.first]
        : const [];
    _game = GameState.playing(
      answer: _answer,
      wordLength: _config.wordLength,
      maxAttempts: _config.maxAttempts,
      lockedPrefix: _lockedPrefix,
    );
    input.value = _game.input; // stage the locked prefix for the active row

    emit(
      state.copyWith(
        tier: tier,
        phase: PracticePhase.playing,
        guesses: const [],
        keyStates: const {},
        answer: _answer,
        answerDefinition: _definition,
        reward: 0,
        roundNonce: state.roundNonce + 1,
      ),
    );
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
      _bumpShake(invalid: true);
      return;
    }

    _game = _game.submit();
    input.value = _game.input;
    emit(_build(phase: PracticePhase.playing));

    if (_game.isTerminal) {
      await Future.delayed(revealDuration);
      if (isClosed) return;
      await _applyOutcome();
    }
  }

  Future<void> _applyOutcome() async {
    if (_game.status == GameStatus.won) {
      final reward = _config.practiceReward(_tier);
      await _wallet.creditCoins(reward, reason: 'practice_${_tier.name}');
      _session = _session.recordSolved(reward);
      await _repository.save(_session);
      emit(_build(phase: PracticePhase.solved, reward: reward));
    } else {
      _session = _session.recordFailed();
      await _repository.save(_session);
      emit(_build(phase: PracticePhase.failed));
    }
  }

  /// Play again at the same tier.
  Future<void> again() async {
    await _maybeInterstitial();
    start(_tier);
  }

  /// Advance to the next harder tier (capped at the hardest).
  Future<void> nextTier() async {
    await _maybeInterstitial();
    final tiers = PracticeTier.values;
    final next = tiers[(_tier.index + 1).clamp(0, tiers.length - 1)];
    start(next);
  }

  Future<void> _maybeInterstitial() async {
    if (_removeAds) return;
    final every = _config.practiceInterstitialEvery;
    if (_session.solved > 0 && _session.solved % every == 0) {
      await _rewardGateway.showInterstitial(InterstitialPlacement.practice);
    }
  }

  void revealLetter() {
    final letter = HintEngine.nextCorrectLetter(_game);
    if (letter == null) return;
    addLetter(letter);
  }

  Set<LogicalLetter> get _knownLetters => {
    ..._game.keyboardStates.keys,
    ..._hintOverrides.keys,
  };

  /// Whether the clean-keyboard hint can gray at least one new letter (req b).
  bool get canCleanKeyboard =>
      _game.status == GameStatus.playing &&
      HintEngine.absentCandidates(_answer, _knownLetters).isNotEmpty;

  /// Atomically buys the clean-keyboard hint: gates on availability, charges via
  /// [pay] only when an effect occurs, refunds via [refund] on failure (req b/c).
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

  /// Atomically buys the Lugʻat (definition) hint: gates on availability, charges
  /// via [pay] only then, displays via [reveal], refunds via [refund] if display
  /// fails (WS1 req c). [reveal] returns whether the definition was displayed.
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

  /// Grays up to [GameConfig.hintCleanCount] genuinely-absent letters (however
  /// many qualify, min 1). Returns the letters grayed — empty when none qualify.
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

  void _bumpShake({required bool invalid}) {
    emit(state.copyWith(shakeSignal: state.shakeSignal + 1, invalidWord: invalid));
  }

  PracticeState _build({required PracticePhase phase, int? reward}) =>
      state.copyWith(
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
