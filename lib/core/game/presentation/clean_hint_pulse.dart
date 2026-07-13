import 'package:flutter/foundation.dart';

import '../domain/logical_letter.dart';

/// One-shot signal fired by a game cubit when the clean-keyboard hint grays a
/// batch of letters. Drives the keyboard's staggered fade-to-absent animation:
/// [letters] are in reveal order (stagger index = position) and [nonce] makes
/// each pulse distinct so the widget can react to repeats.
@immutable
class CleanHintPulse {
  const CleanHintPulse({required this.letters, required this.nonce});

  final List<LogicalLetter> letters;
  final int nonce;
}
