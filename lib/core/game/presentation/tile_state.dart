import 'package:equatable/equatable.dart';

import '../domain/letter_result.dart';

/// Visual state of a board tile (component_spec (b) — 5 states).
enum TileState {
  empty,
  typing, // filled, not submitted
  absent,
  present,
  correct;

  bool get isRevealed =>
      this == TileState.absent ||
      this == TileState.present ||
      this == TileState.correct;

  static TileState fromResult(LetterResult r) => switch (r) {
    LetterResult.absent => TileState.absent,
    LetterResult.present => TileState.present,
    LetterResult.correct => TileState.correct,
  };
}

/// Immutable data a single tile renders: its [letter] glyph (may be null) and
/// visual [state]. Drives a per-tile `ValueNotifier` so one tile's change never
/// rebuilds the board.
class TileData extends Equatable {
  const TileData({this.letter, required this.state});

  const TileData.empty() : letter = null, state = TileState.empty;

  final String? letter;
  final TileState state;

  @override
  List<Object?> get props => [letter, state];
}
