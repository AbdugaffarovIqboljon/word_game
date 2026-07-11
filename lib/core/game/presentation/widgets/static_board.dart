import 'package:flutter/material.dart';

import '../../domain/guess.dart';
import '../tile_state.dart';
import 'static_tile.dart';

/// Non-animated board used for the solved recap (30px) and fail (42px) layouts.
/// Renders each [Guess] as revealed tiles; optionally pads to [rows] with empty
/// tiles. 6px grid gap in both directions (component_spec (b)).
class StaticBoard extends StatelessWidget {
  const StaticBoard({
    required this.guesses,
    required this.columns,
    this.rows,
    this.tileSize = 30,
    this.gap = 6,
    super.key,
  });

  final List<Guess> guesses;
  final int columns;
  final int? rows;
  final double tileSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final totalRows = rows ?? guesses.length;
    final children = <Widget>[];
    for (var r = 0; r < totalRows; r++) {
      if (r > 0) children.add(SizedBox(height: gap));
      children.add(_row(r));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _row(int r) {
    final guess = r < guesses.length ? guesses[r] : null;
    final tiles = <Widget>[];
    for (var c = 0; c < columns; c++) {
      if (c > 0) tiles.add(SizedBox(width: gap));
      final data = guess == null
          ? const TileData.empty()
          : TileData(
              letter: guess.letters[c].glyph,
              state: TileState.fromResult(guess.results[c]),
            );
      tiles.add(StaticTile(data: data, size: tileSize));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: tiles);
  }
}
