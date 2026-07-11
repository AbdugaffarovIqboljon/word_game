import 'package:equatable/equatable.dart';

import 'letter_result.dart';
import 'logical_letter.dart';

/// A submitted, evaluated guess row: its [letters] and the per-letter [results].
/// The two lists are always the same length.
class Guess extends Equatable {
  const Guess({required this.letters, required this.results})
    : assert(letters.length == results.length, 'letters/results length mismatch');

  final List<LogicalLetter> letters;
  final List<LetterResult> results;

  bool get isWinning => results.every((r) => r == LetterResult.correct);

  /// This row's emoji line for the share grid.
  String get emojiLine => results.map((r) => r.emoji).join();

  @override
  List<Object?> get props => [letters, results];
}
