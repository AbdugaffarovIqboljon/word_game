import 'dart:math';

import '../../../core/game/domain/game_state.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/uzbek_alphabet.dart';

/// Pure selection logic for the two board-affecting hints. No Flutter, no state
/// — just "which letter / which keys" so it is unit-testable.
abstract final class HintEngine {
  const HintEngine._();

  /// The correct letter for the next empty slot of the current row, or null if
  /// the row is full / game not playable. "reveal-letter" fills this in.
  static LogicalLetter? nextCorrectLetter(GameState game) {
    if (game.status != GameStatus.playing) return null;
    final pos = game.input.length;
    if (pos >= game.answer.length) return null;
    return game.answer[pos];
  }

  /// Every letter that still qualifies for the clean-keyboard hint: genuinely
  /// absent (not in the [answer]) AND not already known — i.e. not yet revealed
  /// as absent on the keyboard and not used in any submitted guess (both live in
  /// [alreadyMarked]). Order follows the keyboard layout so the caller can apply
  /// a deterministic stagger.
  static List<LogicalLetter> absentCandidates(
    List<LogicalLetter> answer,
    Set<LogicalLetter> alreadyMarked,
  ) {
    final answerSet = answer.toSet();
    return UzbekAlphabet.letters
        .where((l) => !answerSet.contains(l) && !alreadyMarked.contains(l))
        .toList();
  }

  /// Picks up to [count] qualifying [absentCandidates] to gray out. Returns
  /// however many exist when fewer than [count] qualify, and an empty list when
  /// none do (the caller must then treat the hint as unavailable / not charge).
  static List<LogicalLetter> pickAbsentLetters(
    List<LogicalLetter> answer,
    Set<LogicalLetter> alreadyMarked, {
    required int count,
    Random? random,
  }) {
    final candidates = absentCandidates(answer, alreadyMarked);
    if (random != null) candidates.shuffle(random);
    return candidates.take(count).toList();
  }
}
