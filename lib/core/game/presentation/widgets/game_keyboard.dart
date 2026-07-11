import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../domain/letter_result.dart';
import '../../domain/logical_letter.dart';
import '../keyboard_layout.dart';
import 'keyboard_key_button.dart';

/// The full 29-key Uzbek keyboard.
///
/// Rebuilds from [keyStates] (a submit is infrequent, so a single
/// [ValueListenableBuilder] over the whole keyboard is right — the per-key hot
/// path is the press animation, which lives in [KeyboardKeyButton]). Letter keys
/// are colored by best-known state; action keys are always neutral; compound
/// keys in `default` state carry the amber accent border (component_spec (a)).
class GameKeyboard extends StatelessWidget {
  const GameKeyboard({
    required this.keyStates,
    required this.onLetter,
    required this.onEnter,
    required this.onDelete,
    super.key,
  });

  final ValueListenable<Map<LogicalLetter, LetterResult>> keyStates;
  final ValueChanged<LogicalLetter> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onDelete;

  static const double _keyGap = 5;
  static const double _rowGap = 7;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<LogicalLetter, LetterResult>>(
      valueListenable: keyStates,
      builder: (context, states, _) {
        final rows = <Widget>[];
        for (var r = 0; r < KeyboardLayout.rows.length; r++) {
          if (r > 0) rows.add(const SizedBox(height: _rowGap));
          rows.add(
            _KeyboardRow(
              states: states,
              keys: KeyboardLayout.rows[r],
              onLetter: onLetter,
              onEnter: onEnter,
              onDelete: onDelete,
            ),
          );
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  const _KeyboardRow({
    required this.states,
    required this.keys,
    required this.onLetter,
    required this.onEnter,
    required this.onDelete,
  });

  final Map<LogicalLetter, LetterResult> states;
  final List<KeyDef> keys;
  final ValueChanged<LogicalLetter> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) children.add(const SizedBox(width: GameKeyboard._keyGap));
      children.add(Expanded(flex: keys[i].flex, child: _key(keys[i])));
    }
    return Row(children: children);
  }

  Widget _key(KeyDef def) {
    if (def.isAction) {
      final isEnter = def.action == KeyAction.enter;
      return KeyboardKeyButton(
        label: def.label,
        // ENTER renders as the ↵ icon (mirrors ⌫); ⌫ stays a text glyph.
        icon: isEnter ? AppIcons.enter : null,
        fontSize: def.fontSize,
        background: AppColors.muted,
        foreground: AppColors.onKeyDefault,
        onTap: isEnter ? onEnter : onDelete,
      );
    }

    final letter = def.letter!;
    final visual = _KeyVisual.forState(states[letter], isCompound: def.isCompound);
    return KeyboardKeyButton(
      label: def.label,
      fontSize: def.fontSize,
      background: visual.bg,
      foreground: visual.fg,
      border: visual.border,
      onTap: () => onLetter(letter),
    );
  }
}

class _KeyVisual {
  const _KeyVisual(this.bg, this.fg, this.border);
  final Color bg;
  final Color fg;
  final Border? border;

  static const Border _compoundAccent = Border.fromBorderSide(
    BorderSide(color: AppColors.present, width: 1.5),
  );

  /// Resolves a letter key's visual. Compound keys only keep the amber accent
  /// while still in default state (component_spec (a)).
  factory _KeyVisual.forState(LetterResult? state, {required bool isCompound}) {
    switch (state) {
      case null:
        return _KeyVisual(
          AppColors.keyDefault,
          AppColors.onKeyDefault,
          isCompound ? _compoundAccent : null,
        );
      case LetterResult.absent:
        return const _KeyVisual(
          AppColors.keyAbsentBg,
          AppColors.keyAbsentFg,
          null,
        );
      case LetterResult.present:
        return const _KeyVisual(AppColors.present, AppColors.onPresent, null);
      case LetterResult.correct:
        return const _KeyVisual(AppColors.correct, AppColors.onCorrect, null);
    }
  }
}
