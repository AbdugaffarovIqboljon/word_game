import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/presentation/board_controller.dart';
import 'package:word_game/core/game/presentation/tile_state.dart';

/// The locked first letter (WS4) is shown only on the active row, never
/// pre-filled on future not-yet-reached rows (owner device feedback).
void main() {
  const k = LogicalLetter('k');

  test('locked prefix renders on the active row only', () {
    final board = BoardController(rows: 5, columns: 5);
    addTearDown(board.dispose);

    board.setLockedPrefix([k]);
    board.setInput(0, [k]); // active row starts on the locked letter

    // Active row: first tile is the green locked letter, rest empty.
    expect(board.tiles[0][0].value.state, TileState.correct);
    expect(board.tiles[0][1].value.state, TileState.empty);

    // Future rows: completely empty — no pre-filled first letter.
    for (var r = 1; r < 5; r++) {
      expect(board.tiles[r][0].value.state, TileState.empty,
          reason: 'row $r first tile must be blank until reached');
      expect(board.tiles[r][0].value.letter, isNull);
    }
  });

  test('typing keeps the locked first tile green and fills the rest', () {
    final board = BoardController(rows: 5, columns: 5);
    addTearDown(board.dispose);

    board.setLockedPrefix([k]);
    board.setInput(0, [k, const LogicalLetter('o'), const LogicalLetter('b')]);

    expect(board.tiles[0][0].value.state, TileState.correct); // locked
    expect(board.tiles[0][1].value.state, TileState.typing);
    expect(board.tiles[0][2].value.state, TileState.typing);
    expect(board.tiles[0][3].value.state, TileState.empty);
    // Still no bleed into future rows.
    expect(board.tiles[1][0].value.state, TileState.empty);
  });
}
