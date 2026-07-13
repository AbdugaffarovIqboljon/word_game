import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/app_haptics.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../domain/letter_result.dart';
import '../../domain/logical_letter.dart';
import '../clean_hint_pulse.dart';
import '../keyboard_layout.dart';
import 'keyboard_key_button.dart';

/// The full 29-key Uzbek keyboard.
///
/// Rebuilds from [keyStates] (a submit is infrequent, so a single
/// [ValueListenableBuilder] over the whole keyboard is right — the per-key hot
/// path is the press animation, which lives in [KeyboardKeyButton]). Letter keys
/// are colored by best-known state; action keys are always neutral; compound
/// keys render exactly like regular letter keys (component_spec (a)).
///
/// [cleanPulse] drives the clean-keyboard hint's staggered fade-to-absent + a
/// light haptic (WS3). [enabledLetters], when non-null, restricts which letter
/// keys are tappable — the guided tutorial uses it to force the first word.
class GameKeyboard extends StatefulWidget {
  const GameKeyboard({
    required this.keyStates,
    required this.onLetter,
    required this.onEnter,
    required this.onDelete,
    this.cleanPulse,
    this.enabledLetters,
    super.key,
  });

  final ValueListenable<Map<LogicalLetter, LetterResult>> keyStates;
  final ValueChanged<LogicalLetter> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onDelete;
  final ValueListenable<CleanHintPulse?>? cleanPulse;
  final Set<LogicalLetter>? enabledLetters;

  static const double _keyGap = 5;
  static const double _rowGap = 7;
  static const int _cleanStaggerMs = 60;

  @override
  State<GameKeyboard> createState() => _GameKeyboardState();
}

class _GameKeyboardState extends State<GameKeyboard> {
  /// Letter → stagger index for the in-flight clean-hint fade (empty otherwise).
  Map<LogicalLetter, int> _stagger = const {};
  int _lastPulseNonce = 0;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    widget.cleanPulse?.addListener(_onPulse);
  }

  @override
  void didUpdateWidget(covariant GameKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cleanPulse != widget.cleanPulse) {
      oldWidget.cleanPulse?.removeListener(_onPulse);
      widget.cleanPulse?.addListener(_onPulse);
    }
  }

  void _onPulse() {
    final pulse = widget.cleanPulse?.value;
    if (pulse == null || pulse.nonce == _lastPulseNonce) return;
    _lastPulseNonce = pulse.nonce;
    AppHaptics.light();
    setState(() {
      _stagger = {
        for (var i = 0; i < pulse.letters.length; i++) pulse.letters[i]: i,
      };
    });
    // Hold the stagger map until every key has finished fading, then drop it so
    // later unrelated rebuilds don't re-delay.
    _clearTimer?.cancel();
    final holdMs = pulse.letters.length * GameKeyboard._cleanStaggerMs + 320;
    _clearTimer = Timer(Duration(milliseconds: holdMs), () {
      if (mounted) setState(() => _stagger = const {});
    });
  }

  @override
  void dispose() {
    widget.cleanPulse?.removeListener(_onPulse);
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<LogicalLetter, LetterResult>>(
      valueListenable: widget.keyStates,
      builder: (context, states, _) {
        final rows = <Widget>[];
        for (var r = 0; r < KeyboardLayout.rows.length; r++) {
          if (r > 0) rows.add(const SizedBox(height: GameKeyboard._rowGap));
          rows.add(
            _KeyboardRow(
              states: states,
              keys: KeyboardLayout.rows[r],
              onLetter: widget.onLetter,
              onEnter: widget.onEnter,
              onDelete: widget.onDelete,
              stagger: _stagger,
              enabledLetters: widget.enabledLetters,
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
    required this.stagger,
    required this.enabledLetters,
  });

  final Map<LogicalLetter, LetterResult> states;
  final List<KeyDef> keys;
  final ValueChanged<LogicalLetter> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onDelete;
  final Map<LogicalLetter, int> stagger;
  final Set<LogicalLetter>? enabledLetters;

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
    final disabled =
        enabledLetters != null && !enabledLetters!.contains(letter);
    final visual = disabled
        ? const _KeyVisual(AppColors.disabledBg, AppColors.disabledFg)
        : _KeyVisual.forState(states[letter]);
    final delayIndex = stagger[letter];
    return KeyboardKeyButton(
      label: def.label,
      fontSize: def.fontSize,
      background: visual.bg,
      foreground: visual.fg,
      fadeDelay: delayIndex == null
          ? Duration.zero
          : Duration(milliseconds: delayIndex * GameKeyboard._cleanStaggerMs),
      onTap: disabled ? null : () => onLetter(letter),
    );
  }
}

class _KeyVisual {
  const _KeyVisual(this.bg, this.fg);
  final Color bg;
  final Color fg;

  /// Resolves a letter key's visual. Compound keys share the regular letter-key
  /// visuals — they are distinguished by their two-character label alone
  /// (component_spec (a) / decisions §10).
  factory _KeyVisual.forState(LetterResult? state) {
    switch (state) {
      case null:
        return const _KeyVisual(AppColors.keyDefault, AppColors.onKeyDefault);
      case LetterResult.absent:
        return const _KeyVisual(AppColors.keyAbsentBg, AppColors.keyAbsentFg);
      case LetterResult.present:
        return const _KeyVisual(AppColors.present, AppColors.onPresent);
      case LetterResult.correct:
        return const _KeyVisual(AppColors.correct, AppColors.onCorrect);
    }
  }
}
