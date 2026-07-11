/// Outcome of a single guessed letter after a submission.
///
/// - [absent]  → not in the answer (tile `#35435F`, key `#212D45`, emoji ⬛)
/// - [present] → in the answer, wrong position (tile/key `#C2952B`, emoji 🟨)
/// - [correct] → in the answer, correct position (tile/key `#3E9B54`, emoji 🟩)
enum LetterResult {
  absent,
  present,
  correct;

  /// Best-known-state rank for keyboard aggregation: correct > present > absent
  /// (decisions §7).
  int get priority => switch (this) {
    LetterResult.absent => 1,
    LetterResult.present => 2,
    LetterResult.correct => 3,
  };

  /// Emoji glyph for the shareable grid (component_spec (c)).
  String get emoji => switch (this) {
    LetterResult.absent => '⬛',
    LetterResult.present => '🟨',
    LetterResult.correct => '🟩',
  };
}
