import 'logical_letter.dart';

/// Word-source abstraction the game engine depends on. Kept an interface so the
/// engine never knows whether words come from a bundled asset, a network fetch,
/// or an in-memory test fake.
///
/// v1 ships [InMemoryDictionary] seeded with a small curated list — the real
/// word source (bundled asset / server) is a documented fake (see the phase
/// report's faked-dependencies list).
abstract interface class Dictionary {
  /// Whether [word] is an allowed guess.
  bool contains(List<LogicalLetter> word);

  /// The deterministic answer for a given puzzle [date] (local rollover date).
  List<LogicalLetter> answerForDate(DateTime date);

  /// A one-line definition for the fail-state answer card and the dictionary
  /// hint; null if unknown.
  String? definitionFor(List<LogicalLetter> word);

  /// Stable, monotonically-increasing puzzle number for [date] (the "#142" in
  /// the share card header).
  int puzzleNumberForDate(DateTime date);
}
