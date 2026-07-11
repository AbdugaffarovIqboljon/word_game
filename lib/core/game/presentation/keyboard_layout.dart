import '../domain/logical_letter.dart';

/// The two non-letter keys, exempt from the 4-state coloring (component_spec (a)).
enum KeyAction { enter, delete }

/// A single keyboard key. Either a letter key (colored by game state) or an
/// [action] key (ENTER / ⌫, always neutral). Kept const with primitive fields;
/// the [LogicalLetter] is built lazily from [_letterValue].
class KeyDef {
  const KeyDef.letter(this.label, String value, {this.isCompound = false})
    : _letterValue = value,
      action = null;

  const KeyDef.action(this.label, this.action)
    : _letterValue = null,
      isCompound = false;

  final String label;
  final String? _letterValue;
  final KeyAction? action;
  final bool isCompound;

  bool get isAction => action != null;

  /// The canonical logical letter for a letter key (null for action keys).
  LogicalLetter? get letter =>
      _letterValue == null ? null : LogicalLetter(_letterValue);

  /// Flex weight ×20 so the 1 / 1.35 / 1.7 ratios stay integers
  /// (Flexible.flex is an int): 20 / 27 / 34.
  int get flex => isAction ? 34 : (isCompound ? 27 : 20);

  /// Label font size (component_spec (a)): 17 letter, 15 compound/action.
  double get fontSize => isCompound || isAction ? 15 : 17;
}

/// The exact 29-key Uzbek layout (component_spec (a)):
/// Row 1: Q E R T Y U I O P Oʻ
/// Row 2: A S D F G H J K L Gʻ
/// Row 3: ENTER Z X V B N M Sh Ch Ng ⌫
abstract final class KeyboardLayout {
  const KeyboardLayout._();

  static const List<List<KeyDef>> rows = [
    [
      KeyDef.letter('Q', 'q'),
      KeyDef.letter('E', 'e'),
      KeyDef.letter('R', 'r'),
      KeyDef.letter('T', 't'),
      KeyDef.letter('Y', 'y'),
      KeyDef.letter('U', 'u'),
      KeyDef.letter('I', 'i'),
      KeyDef.letter('O', 'o'),
      KeyDef.letter('P', 'p'),
      KeyDef.letter('Oʻ', 'oʻ', isCompound: true),
    ],
    [
      KeyDef.letter('A', 'a'),
      KeyDef.letter('S', 's'),
      KeyDef.letter('D', 'd'),
      KeyDef.letter('F', 'f'),
      KeyDef.letter('G', 'g'),
      KeyDef.letter('H', 'h'),
      KeyDef.letter('J', 'j'),
      KeyDef.letter('K', 'k'),
      KeyDef.letter('L', 'l'),
      KeyDef.letter('Gʻ', 'gʻ', isCompound: true),
    ],
    [
      KeyDef.action('ENTER', KeyAction.enter),
      KeyDef.letter('Z', 'z'),
      KeyDef.letter('X', 'x'),
      KeyDef.letter('V', 'v'),
      KeyDef.letter('B', 'b'),
      KeyDef.letter('N', 'n'),
      KeyDef.letter('M', 'm'),
      KeyDef.letter('Sh', 'sh', isCompound: true),
      KeyDef.letter('Ch', 'ch', isCompound: true),
      KeyDef.letter('Ng', 'ng', isCompound: true),
      KeyDef.action('⌫', KeyAction.delete),
    ],
  ];
}
