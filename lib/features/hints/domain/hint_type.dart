/// The three daily/practice hints (screen_inventory §4).
enum HintType {
  /// Reveals one correct-position letter (fills the next slot).
  revealLetter,

  /// Grays out several absent letters on the keyboard.
  cleanKeyboard,

  /// Shows the word's dictionary definition (no ad option).
  dictionary,
}
