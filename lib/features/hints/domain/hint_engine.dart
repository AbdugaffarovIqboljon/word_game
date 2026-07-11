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

  /// Picks up to [count] letters that are genuinely absent (not in the answer)
  /// and not already marked, to gray out on the keyboard.
  static List<LogicalLetter> pickAbsentLetters(
    List<LogicalLetter> answer,
    Set<LogicalLetter> alreadyMarked, {
    required int count,
    Random? random,
  }) {
    final answerSet = answer.toSet();
    final candidates = UzbekAlphabet.letters
        .where((l) => !answerSet.contains(l) && !alreadyMarked.contains(l))
        .toList();
    if (random != null) candidates.shuffle(random);
    return candidates.take(count).toList();
  }
}
