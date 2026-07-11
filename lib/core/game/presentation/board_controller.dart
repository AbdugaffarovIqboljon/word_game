import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/guess.dart';
import '../domain/logical_letter.dart';
import 'tile_state.dart';

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
      );

  final int rows;
  final int columns;
  final List<List<ValueNotifier<TileData>>> tiles;

  /// Bumped to trigger a single-shot shake on that row.
  final List<ValueNotifier<int>> rowShake;

  final List<Timer> _timers = [];
  bool _disposed = false;

  static const _staggerMs = 100;

  /// Reflects the current, unsubmitted input row (typing tiles).
  void setInput(int row, List<LogicalLetter> letters) {
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

  void clear() {
    for (final row in tiles) {
      for (final tile in row) {
        tile.value = const TileData.empty();
      }
    }
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
  }
}
