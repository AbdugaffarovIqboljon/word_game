import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/features/notifications/domain/notification_prompt_policy.dart';

void main() {
  group('shouldPrompt', () {
    test('asks on the first solve', () {
      expect(
        NotificationPromptPolicy.shouldPrompt(
          solveCount: 1,
          stage: NotificationPromptStage.notAsked,
        ),
        isTrue,
      );
    });

    test('does not ask before any solve', () {
      expect(
        NotificationPromptPolicy.shouldPrompt(
          solveCount: 0,
          stage: NotificationPromptStage.notAsked,
        ),
        isFalse,
      );
    });

    test('after a postpone, waits until the third solve', () {
      expect(
        NotificationPromptPolicy.shouldPrompt(
          solveCount: 2,
          stage: NotificationPromptStage.postponed,
        ),
        isFalse,
      );
      expect(
        NotificationPromptPolicy.shouldPrompt(
          solveCount: 3,
          stage: NotificationPromptStage.postponed,
        ),
        isTrue,
      );
    });

    test('never asks once done', () {
      for (final n in [1, 3, 10]) {
        expect(
          NotificationPromptPolicy.shouldPrompt(
            solveCount: n,
            stage: NotificationPromptStage.done,
          ),
          isFalse,
        );
      }
    });
  });

  group('stage transitions', () {
    test('first postpone → postponed, second postpone → done', () {
      final afterFirst =
          NotificationPromptPolicy.afterPostpone(NotificationPromptStage.notAsked);
      expect(afterFirst, NotificationPromptStage.postponed);
      expect(
        NotificationPromptPolicy.afterPostpone(afterFirst),
        NotificationPromptStage.done,
      );
    });

    test('accept always finishes', () {
      for (final s in NotificationPromptStage.values) {
        expect(
          NotificationPromptPolicy.afterAccept(s),
          NotificationPromptStage.done,
        );
      }
    });
  });

  // Full lifecycle: first solve asks → postpone → 2nd solve silent → 3rd solve
  // asks again → postpone → forever silent.
  test('end-to-end ask cadence', () {
    var stage = NotificationPromptStage.notAsked;

    // Solve 1: prompt shown, user postpones.
    expect(
      NotificationPromptPolicy.shouldPrompt(solveCount: 1, stage: stage),
      isTrue,
    );
    stage = NotificationPromptPolicy.afterPostpone(stage);

    // Solve 2: silent.
    expect(
      NotificationPromptPolicy.shouldPrompt(solveCount: 2, stage: stage),
      isFalse,
    );

    // Solve 3: prompt shown again, user postpones again.
    expect(
      NotificationPromptPolicy.shouldPrompt(solveCount: 3, stage: stage),
      isTrue,
    );
    stage = NotificationPromptPolicy.afterPostpone(stage);
    expect(stage, NotificationPromptStage.done);

    // Solve 4+: never again.
    expect(
      NotificationPromptPolicy.shouldPrompt(solveCount: 4, stage: stage),
      isFalse,
    );
  });
}
