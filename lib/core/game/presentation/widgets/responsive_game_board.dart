import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board_controller.dart';
import 'game_board.dart';

/// Sizes the [GameBoard] to the available width (WS4): the board fills the space
/// left by a side padding of 16 at 360px-class widths and 24 at ≥390px, tiles
/// scaling up to fill it while staying square, keeping the 6px grid gap and
/// never exceeding [maxTile]. On short screens the tile is additionally capped
/// by the available height so the board never overflows the keyboard below.
class ResponsiveGameBoard extends StatelessWidget {
  const ResponsiveGameBoard({
    required this.controller,
    this.boardKey,
    super.key,
  });

  final BoardController controller;

  /// Forwarded to the inner [GameBoard] (the spotlight tour anchors on it).
  final Key? boardKey;

  static const double gap = 6;
  static const double maxTile = 64;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePad = screenWidth >= 390 ? 24.0 : 16.0;
    final boardWidth = screenWidth - 2 * sidePad;
    final cols = controller.columns;
    final rows = controller.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Never exceed the box we're actually given (the scaffold already insets
        // its own padding), so the board can't overflow horizontally.
        final availWidth = math.min(boardWidth, constraints.maxWidth);
        final wTile = (availWidth - (cols - 1) * gap) / cols;
        final hTile = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - (rows - 1) * gap) / rows
            : maxTile;
        final tile = math.min(math.min(wTile, hTile), maxTile);
        return Align(
          alignment: Alignment.topCenter,
          child: GameBoard(
            key: boardKey,
            controller: controller,
            tileSize: tile,
            gap: gap,
          ),
        );
      },
    );
  }
}
