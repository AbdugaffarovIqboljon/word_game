import 'package:flutter/material.dart';

import '../board_controller.dart';
import 'board_row.dart';

/// The interactive 6×5 board, driven by a [BoardController]. Tile size defaults
/// to the 56px main-gameplay context; 6px grid gap in both directions
/// (component_spec (b)). Wrapped in a [RepaintBoundary] to isolate flip/shake
/// repaints from the rest of the screen.
class GameBoard extends StatelessWidget {
  const GameBoard({
    required this.controller,
    this.tileSize = 56,
    this.gap = 6,
    super.key,
  });

  final BoardController controller;
  final double tileSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var r = 0; r < controller.rows; r++) {
      if (r > 0) rows.add(SizedBox(height: gap));
      rows.add(
        BoardRow(
          rowIndex: r,
          tiles: controller.tiles[r],
          shake: controller.rowShake[r],
          bounce: controller.rowBounce[r],
          cursor: controller.cursor,
          tileSize: tileSize,
          gap: gap,
        ),
      );
    }
    return RepaintBoundary(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
