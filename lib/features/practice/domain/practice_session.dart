import 'package:equatable/equatable.dart';

/// Today's practice session totals (resets each day). Shown in the hub's
/// "Bugungi sessiya" row.
class PracticeSession extends Equatable {
  const PracticeSession({
    required this.dateKey,
    this.played = 0,
    this.solved = 0,
    this.coins = 0,
  });

  final String dateKey; // yyyy-mm-dd of the puzzle date
  final int played;
  final int solved;
  final int coins;

  int get accuracyPercent => played == 0 ? 0 : ((solved / played) * 100).round();

  PracticeSession recordSolved(int reward) => PracticeSession(
    dateKey: dateKey,
    played: played + 1,
    solved: solved + 1,
    coins: coins + reward,
  );

  PracticeSession recordFailed() => PracticeSession(
    dateKey: dateKey,
    played: played + 1,
    solved: solved,
    coins: coins,
  );

  Map<String, dynamic> toJson() => {
    'date': dateKey,
    'played': played,
    'solved': solved,
    'coins': coins,
  };

  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      PracticeSession(
        dateKey: json['date'] as String,
        played: json['played'] as int? ?? 0,
        solved: json['solved'] as int? ?? 0,
        coins: json['coins'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [dateKey, played, solved, coins];
}
