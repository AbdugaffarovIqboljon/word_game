import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/game_state.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';

List<LogicalLetter> ll(List<String> xs) => xs.map(LogicalLetter.new).toList();

void main() {
  final answer = ll(['q', 'a', 'l', 'a', 'm']);

  group('GameState machine', () {
    test('idle -> playing via start()', () {
      const idle = GameState.idle();
      expect(idle.status, GameStatus.idle);
      final playing = idle.start(answer);
      expect(playing.status, GameStatus.playing);
      expect(playing.answer, answer);
    });

    test('addLetter respects word length cap', () {
      var state = GameState.playing(answer: answer);
      for (final letter in ll(['x', 'y', 'z', 'w', 'v', 'u'])) {
        state = state.addLetter(letter);
      }
      expect(state.input, hasLength(5)); // 6th ignored
      expect(state.isInputFull, isTrue);
    });

    test('removeLetter pops the last staged letter', () {
      var state = GameState.playing(answer: answer)
          .addLetter(const LogicalLetter('x'))
          .addLetter(const LogicalLetter('y'));
      state = state.removeLetter();
      expect(state.input.map((l) => l.value).toList(), ['x']);
    });

    test('removeLetter on empty input is a no-op', () {
      final state = GameState.playing(answer: answer);
      expect(state.removeLetter(), state);
    });

    test('submit on incomplete row is a no-op', () {
      final state = GameState.playing(answer: answer)
          .addLetter(const LogicalLetter('q'));
      expect(state.submit(), state);
    });

    test('correct guess -> won', () {
      var state = GameState.playing(answer: answer);
      for (final letter in answer) {
        state = state.addLetter(letter);
      }
      state = state.submit();
      expect(state.status, GameStatus.won);
      expect(state.guesses, hasLength(1));
      expect(state.guesses.single.isWinning, isTrue);
    });

    test('six wrong guesses -> lost', () {
      var state = GameState.playing(answer: answer);
      final wrong = ll(['z', 'x', 'v', 'b', 'n']);
      for (var i = 0; i < 6; i++) {
        for (final letter in wrong) {
          state = state.addLetter(letter);
        }
        state = state.submit();
      }
      expect(state.status, GameStatus.lost);
      expect(state.guesses, hasLength(6));
      expect(state.remainingAttempts, 0);
    });

    test('no further input accepted once terminal', () {
      var state = GameState.playing(answer: answer);
      for (final letter in answer) {
        state = state.addLetter(letter);
      }
      state = state.submit(); // won
      final afterAdd = state.addLetter(const LogicalLetter('z'));
      expect(afterAdd.input, isEmpty);
      expect(afterAdd, state);
    });

    test('keyboardStates reflect submitted guesses', () {
      var state = GameState.playing(answer: answer);
      for (final letter in ll(['q', 'a', 'l', 'a', 'm'])) {
        state = state.addLetter(letter);
      }
      state = state.submit();
      final kb = state.keyboardStates;
      expect(kb[const LogicalLetter('q')]!.priority, 3); // correct
    });
  });
}
