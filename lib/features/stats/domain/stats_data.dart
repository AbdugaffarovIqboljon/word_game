import 'package:equatable/equatable.dart';

/// Aggregate play statistics. [distribution] is length [attempts] — index i is
/// the number of games won in (i+1) guesses. [lastWinAttempt] is the attempt
/// count of the most recent win (drives the histogram highlight).
class StatsData extends Equatable {
  StatsData({
    this.played = 0,
    this.wins = 0,
    List<int>? distribution,
    this.lastWinAttempt,
    int attempts = 6,
  }) : distribution = distribution ?? List<int>.filled(attempts, 0);

  final int played;
  final int wins;
  final List<int> distribution;
  final int? lastWinAttempt;

  int get losses => played - wins;
  double get winRate => played == 0 ? 0 : wins / played;
  int get winRatePercent => (winRate * 100).round();
  int get maxInDistribution =>
      distribution.isEmpty ? 0 : distribution.reduce((a, b) => a > b ? a : b);

  StatsData copyWith({
    int? played,
    int? wins,
    List<int>? distribution,
    Object? lastWinAttempt = _keep,
  }) => StatsData(
    played: played ?? this.played,
    wins: wins ?? this.wins,
    distribution: distribution ?? this.distribution,
    lastWinAttempt: lastWinAttempt == _keep
        ? this.lastWinAttempt
        : lastWinAttempt as int?,
  );

  static const Object _keep = Object();

  /// Applies a win at [attempt] (1-based).
  StatsData recordWin(int attempt) {
    final dist = List<int>.of(distribution);
    if (attempt >= 1 && attempt <= dist.length) dist[attempt - 1]++;
    return copyWith(
      played: played + 1,
      wins: wins + 1,
      distribution: dist,
      lastWinAttempt: attempt,
    );
  }

  StatsData recordLoss() => copyWith(played: played + 1);

  Map<String, dynamic> toJson() => {
    'played': played,
    'wins': wins,
    'distribution': distribution,
    'lastWinAttempt': lastWinAttempt,
  };

  factory StatsData.fromJson(Map<String, dynamic> json) => StatsData(
    played: json['played'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    distribution: (json['distribution'] as List?)?.cast<int>(),
    lastWinAttempt: json['lastWinAttempt'] as int?,
  );

  @override
  List<Object?> get props => [played, wins, distribution, lastWinAttempt];
}
