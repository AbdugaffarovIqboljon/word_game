/// Progress of the post-solve notification pre-permission ask (WS2).
enum NotificationPromptStage {
  /// The pre-permission card has never been shown.
  notAsked,

  /// Shown once and the user tapped "Keyinroq" (later).
  postponed,

  /// Resolved — the user accepted (OS prompt shown) or postponed a second time.
  /// The card is never auto-shown again; Settings stays the manual path.
  done,
}

/// Pure decision logic for when to surface the pre-permission card and how the
/// stage advances. No Flutter, no storage — fully unit-testable.
///
/// Policy: ask on the FIRST daily solve (win or loss); if postponed, ask again
/// after the THIRD solve; then never auto-ask again.
abstract final class NotificationPromptPolicy {
  const NotificationPromptPolicy._();

  /// Whether to show the card on the result screen given the number of daily
  /// puzzles resolved so far ([solveCount], counting wins and losses) and the
  /// current [stage].
  static bool shouldPrompt({
    required int solveCount,
    required NotificationPromptStage stage,
  }) => switch (stage) {
    NotificationPromptStage.done => false,
    NotificationPromptStage.notAsked => solveCount >= 1,
    NotificationPromptStage.postponed => solveCount >= 3,
  };

  /// Stage after the user taps "Keyinroq": postpone once, then finish.
  static NotificationPromptStage afterPostpone(NotificationPromptStage stage) =>
      stage == NotificationPromptStage.notAsked
      ? NotificationPromptStage.postponed
      : NotificationPromptStage.done;

  /// Stage after the user taps "Ha, eslat": always finished (OS prompt shown).
  static NotificationPromptStage afterAccept(NotificationPromptStage stage) =>
      NotificationPromptStage.done;
}
