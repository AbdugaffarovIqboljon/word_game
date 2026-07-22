import 'package:equatable/equatable.dart';

/// Today's practice session totals (resets each day). Shown in the hub's
/// "Bugungi sessiya" row.
class PracticeSession extends Equatable {
  const PracticeSession({
    required this.dateKey,
    this.started = 0,
    this.played = 0,
    this.solved = 0,
    this.coins = 0,
  });

  final String dateKey; // yyyy-mm-dd of the puzzle date

  /// Rounds *begun* today (WS1) — free-round entitlement counts against this and
  /// resets with [dateKey] at Tashkent midnight. Distinct from [played], which
  /// only counts rounds that reached an end.
  final int started;
  final int played;
  final int solved;
  final int coins;

  int get accuracyPercent => played == 0 ? 0 : ((solved / played) * 100).round();

  /// Marks a round as begun (WS1). Called once per round start, so it also
  /// covers rounds the player abandons before finishing.
  PracticeSession recordStarted() => PracticeSession(
    dateKey: dateKey,
    started: started + 1,
    played: played,
    solved: solved,
    coins: coins,
  );

  PracticeSession recordSolved(int reward) => PracticeSession(
    dateKey: dateKey,
    started: started,
    played: played + 1,
    solved: solved + 1,
    coins: coins + reward,
  );

  PracticeSession recordFailed() => PracticeSession(
    dateKey: dateKey,
    started: started,
    played: played + 1,
    solved: solved,
    coins: coins,
  );

  Map<String, dynamic> toJson() => {
    'date': dateKey,
    'started': started,
    'played': played,
    'solved': solved,
    'coins': coins,
  };

  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      PracticeSession(
        dateKey: json['date'] as String,
        started: json['started'] as int? ?? 0,
        played: json['played'] as int? ?? 0,
        solved: json['solved'] as int? ?? 0,
        coins: json['coins'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [dateKey, started, played, solved, coins];
}
