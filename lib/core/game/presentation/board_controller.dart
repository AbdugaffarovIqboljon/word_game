import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/guess.dart';
import '../domain/logical_letter.dart';
import 'tile_state.dart';

/// The live typing position: [row] is the row currently being typed ( -1 when
/// none, e.g. a resolved board), [col] is the next-empty column in that row
/// (equal to the row length when the row is full). Drives the active-row
/// highlight and the pulsing next-empty tile.
@immutable
class BoardCursor {
  const BoardCursor(this.row, this.col);
  const BoardCursor.none() : row = -1, col = -1;

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is BoardCursor && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// Owns the per-tile [ValueNotifier]s and per-row shake triggers for one board.
///
/// Created in a screen's `initState` and disposed in `dispose`. The screen's
/// game Cubit pushes changes here imperatively (set typing row, reveal a
/// submitted row with stagger, shake an invalid row) so that typing a letter
/// updates exactly one tile notifier and never rebuilds the whole board.
class BoardController {
  BoardController({required this.rows, required this.columns})
    : tiles = List.generate(
        rows,
        (_) => List.generate(
          columns,
          (_) => ValueNotifier<TileData>(const TileData.empty()),
          growable: false,
        ),
        growable: false,
      ),
      rowShake = List.generate(
        rows,
        (_) => ValueNotifier<int>(0),
        growable: false,
      ),
      rowBounce = List.generate(
        rows,
        (_) => ValueNotifier<int>(0),
        growable: false,
      );

  final int rows;
  final int columns;
  final List<List<ValueNotifier<TileData>>> tiles;

  /// Bumped to trigger a single-shot shake on that row.
  final List<ValueNotifier<int>> rowShake;

  /// Bumped to trigger a single-shot per-tile win bounce on that row.
  final List<ValueNotifier<int>> rowBounce;

  /// The current typing position (active-row highlight + next-empty pulse).
  final ValueNotifier<BoardCursor> cursor =
      ValueNotifier(const BoardCursor.none());

  final List<Timer> _timers = [];
  bool _disposed = false;

  static const _staggerMs = 100;

  /// Moves the typing cursor. Pass [row] `-1` to hide the active-row feedback.
  void setCursor(int row, int col) {
    if (!_disposed) cursor.value = BoardCursor(row, col);
  }

  /// Reflects the current, unsubmitted input row (typing tiles). No-ops when the
  /// row is past the board — after the final guess `currentRow` equals [rows].
  void setInput(int row, List<LogicalLetter> letters) {
    if (row < 0 || row >= rows) return;
    for (var c = 0; c < columns; c++) {
      tiles[row][c].value = c < letters.length
          ? TileData(letter: letters[c].glyph, state: TileState.typing)
          : const TileData.empty();
    }
  }

  /// Reveals a submitted [guess] on [row] with the 100ms per-tile stagger; each
  /// tile flips itself on its result color.
  void revealRow(int row, Guess guess) {
    for (var c = 0; c < columns; c++) {
      final data = TileData(
        letter: guess.letters[c].glyph,
        state: TileState.fromResult(guess.results[c]),
      );
      final timer = Timer(Duration(milliseconds: c * _staggerMs), () {
        if (_disposed) return;
        tiles[row][c].value = data;
      });
      _timers.add(timer);
    }
  }

  /// Renders a fully-known row immediately (no flip) — used when restoring a
  /// persisted board on launch.
  void restoreRow(int row, Guess guess) {
    for (var c = 0; c < columns; c++) {
      tiles[row][c].value = TileData(
        letter: guess.letters[c].glyph,
        state: TileState.fromResult(guess.results[c]),
      );
    }
  }

  void shakeRow(int row) {
    if (!_disposed) rowShake[row].value++;
  }

  /// Runs the staggered win bounce on [row] (component_spec motion / win).
  void bounceRow(int row) {
    if (!_disposed && row >= 0 && row < rows) rowBounce[row].value++;
  }

  void clear() {
    for (final row in tiles) {
      for (final tile in row) {
        tile.value = const TileData.empty();
      }
    }
    cursor.value = const BoardCursor.none();
  }

  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final row in tiles) {
      for (final tile in row) {
        tile.dispose();
      }
    }
    for (final shake in rowShake) {
      shake.dispose();
    }
    for (final bounce in rowBounce) {
      bounce.dispose();
    }
    cursor.dispose();
  }
}
