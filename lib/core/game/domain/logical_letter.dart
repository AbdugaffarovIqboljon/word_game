import 'package:equatable/equatable.dart';

/// One logical letter of the Uzbek Latin alphabet.
///
/// A logical letter is the atomic unit of the game — it may map to one Unicode
/// character (`q`, `a`) or two (the compound letters `oʻ`, `gʻ`, `sh`, `ch`,
/// `ng`), but it always occupies exactly one board tile and one keyboard key.
///
/// [value] is the canonical form: lowercase, with the modifier turned-comma
/// normalized to U+02BB. Equality/counting are done on [value]; [glyph] is the
/// uppercase form shown on tiles.
class LogicalLetter extends Equatable {
  const LogicalLetter(this.value);

  /// Canonical lowercase form, e.g. `q`, `oʻ` (`o` + U+02BB), `sh`.
  final String value;

  /// True for the two-character compound letters (Oʻ Gʻ Sh Ch Ng).
  bool get isCompound => value.length > 1;

  /// Uppercase form for tile rendering (`sh` → `SH`, `oʻ` → `Oʻ`).
  String get glyph => value.toUpperCase();

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
