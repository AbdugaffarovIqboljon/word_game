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
    this.bonusPlayed = 0,
    this.bonusSolved = 0,
    int attempts = 5, // WS4: 5 attempts
  }) : distribution = distribution ?? List<int>.filled(attempts, 0);

  final int played;
  final int wins;
  final List<int> distribution;
  final int? lastWinAttempt;

  // WS3: bonus-word ("Yana yechish") totals — kept separate from the daily stats
  // so they never affect the streak, share grid or win histogram.
  final int bonusPlayed;
  final int bonusSolved;

  int get losses => played - wins;
  double get winRate => played == 0 ? 0 : wins / played;
  int get winRatePercent => (winRate * 100).round();
  int get bonusWinRatePercent =>
      bonusPlayed == 0 ? 0 : ((bonusSolved / bonusPlayed) * 100).round();
  int get maxInDistribution =>
      distribution.isEmpty ? 0 : distribution.reduce((a, b) => a > b ? a : b);

  StatsData copyWith({
    int? played,
    int? wins,
    List<int>? distribution,
    Object? lastWinAttempt = _keep,
    int? bonusPlayed,
    int? bonusSolved,
  }) => StatsData(
    played: played ?? this.played,
    wins: wins ?? this.wins,
    distribution: distribution ?? this.distribution,
    lastWinAttempt: lastWinAttempt == _keep
        ? this.lastWinAttempt
        : lastWinAttempt as int?,
    bonusPlayed: bonusPlayed ?? this.bonusPlayed,
    bonusSolved: bonusSolved ?? this.bonusSolved,
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

  /// WS3: a solved/failed bonus word — tallied only into the bonus counters.
  StatsData recordBonusWin() =>
      copyWith(bonusPlayed: bonusPlayed + 1, bonusSolved: bonusSolved + 1);

  StatsData recordBonusLoss() => copyWith(bonusPlayed: bonusPlayed + 1);

  Map<String, dynamic> toJson() => {
    'played': played,
    'wins': wins,
    'distribution': distribution,
    'lastWinAttempt': lastWinAttempt,
    'bonusPlayed': bonusPlayed,
    'bonusSolved': bonusSolved,
  };

  factory StatsData.fromJson(Map<String, dynamic> json) {
    final lastWin = json['lastWinAttempt'] as int?;
    return StatsData(
      played: json['played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      distribution: _migrateDistribution((json['distribution'] as List?)?.cast<int>()),
      // A legacy 6-attempt win collapses onto the new 5th bucket.
      lastWinAttempt: lastWin == null ? null : (lastWin > 5 ? 5 : lastWin),
      bonusPlayed: json['bonusPlayed'] as int? ?? 0, // absent in pre-WS3 data
      bonusSolved: json['bonusSolved'] as int? ?? 0,
    );
  }

  /// WS4: migrate a stored 6-bucket (or longer) histogram to 5 by merging every
  /// overflow bucket (row 6+) into row 5, so existing stats survive the attempts
  /// reduction without losing win counts.
  static List<int>? _migrateDistribution(List<int>? dist) {
    if (dist == null || dist.length <= 5) return dist;
    final merged = List<int>.of(dist.sublist(0, 5));
    for (var i = 5; i < dist.length; i++) {
      merged[4] += dist[i];
    }
    return merged;
  }

  @override
  List<Object?> get props =>
      [played, wins, distribution, lastWinAttempt, bonusPlayed, bonusSolved];
}
