import '../../../core/storage/preferences_service.dart';
import '../domain/notification_prompt_policy.dart';

/// Persists the state of the post-solve notification pre-permission ask: how
/// many daily puzzles the user has resolved and how far the ask has progressed.
class NotificationPromptRepository {
  NotificationPromptRepository(this._prefs);

  static const _solvesKey = 'notif_prompt_solves';
  static const _stageKey = 'notif_prompt_stage';

  final PreferencesService _prefs;

  /// Number of daily puzzles resolved (wins + losses).
  int get solveCount => _prefs.getInt(_solvesKey);

  Future<void> incrementSolveCount() =>
      _prefs.setInt(_solvesKey, solveCount + 1);

  NotificationPromptStage get stage {
    final i = _prefs.getInt(_stageKey);
    return i >= 0 && i < NotificationPromptStage.values.length
        ? NotificationPromptStage.values[i]
        : NotificationPromptStage.notAsked;
  }

  Future<void> setStage(NotificationPromptStage stage) =>
      _prefs.setInt(_stageKey, stage.index);

  /// Whether the pre-permission card should be shown on the current result.
  bool get shouldPrompt => NotificationPromptPolicy.shouldPrompt(
    solveCount: solveCount,
    stage: stage,
  );
}
