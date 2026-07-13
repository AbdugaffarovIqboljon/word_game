import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/features/onboarding/domain/tutorial_script.dart';

void main() {
  test('answer and first guess are 5 single-letter tiles', () {
    expect(TutorialScript.answer, hasLength(TutorialScript.columns));
    expect(TutorialScript.firstGuess, hasLength(TutorialScript.columns));
    expect(TutorialScript.answer.every((l) => !l.isCompound), isTrue);
    expect(TutorialScript.firstGuess.every((l) => !l.isCompound), isTrue);
  });

  test('the first reveal teaches all three colors', () {
    final results = TutorialScript.firstReveal.results;
    expect(results, contains(LetterResult.correct));
    expect(results, contains(LetterResult.present));
    expect(results, contains(LetterResult.absent));
  });

  test('representative teach indices map to their color', () {
    final r = TutorialScript.firstReveal.results;
    expect(TutorialScript.correctIndex, isNonNegative);
    expect(TutorialScript.presentIndex, isNonNegative);
    expect(TutorialScript.absentIndex, isNonNegative);
    expect(r[TutorialScript.correctIndex], LetterResult.correct);
    expect(r[TutorialScript.presentIndex], LetterResult.present);
    expect(r[TutorialScript.absentIndex], LetterResult.absent);
  });

  test('the first guess is not the answer, and the answer solves it', () {
    expect(TutorialScript.isWin(TutorialScript.firstGuess), isFalse);
    expect(TutorialScript.isWin(TutorialScript.answer), isTrue);
  });

  test('remains solvable in the attempts left after the guided first guess', () {
    // Beat 1 spends one of six rows; the answer is reachable in the rest.
    expect(TutorialScript.rows - 1, greaterThanOrEqualTo(1));
    expect(TutorialScript.answerWord, 'KITOB');
  });
}
