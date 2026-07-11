import 'package:equatable/equatable.dart';

/// Persisted streak state.
///
/// [anchorDate] is the most recent puzzle date through which the streak is
/// unbroken — set on a solve, or moved forward when a freeze covers a missed
/// day. It is what makes freeze consumption idempotent across launches.
/// [brokenStreakValue] / [brokenAtDate] capture a break so it can be repaired
/// within the repair window. All dates are date-only UTC instants.
class StreakData extends Equatable {
  const StreakData({
    this.current = 0,
    this.best = 0,
    this.freezes = 0,
    this.anchorDate,
    this.lastSolvedDate,
    this.brokenStreakValue,
    this.brokenAtDate,
  });

  final int current;
  final int best;
  final int freezes;
  final DateTime? anchorDate;
  final DateTime? lastSolvedDate;
  final int? brokenStreakValue;
  final DateTime? brokenAtDate;

  static const Object _keep = Object();

  StreakData copyWith({
    int? current,
    int? best,
    int? freezes,
    Object? anchorDate = _keep,
    Object? lastSolvedDate = _keep,
    Object? brokenStreakValue = _keep,
    Object? brokenAtDate = _keep,
  }) => StreakData(
    current: current ?? this.current,
    best: best ?? this.best,
    freezes: freezes ?? this.freezes,
    anchorDate: anchorDate == _keep ? this.anchorDate : anchorDate as DateTime?,
    lastSolvedDate: lastSolvedDate == _keep
        ? this.lastSolvedDate
        : lastSolvedDate as DateTime?,
    brokenStreakValue: brokenStreakValue == _keep
        ? this.brokenStreakValue
        : brokenStreakValue as int?,
    brokenAtDate: brokenAtDate == _keep
        ? this.brokenAtDate
        : brokenAtDate as DateTime?,
  );

  Map<String, dynamic> toJson() => {
    'current': current,
    'best': best,
    'freezes': freezes,
    'anchor': anchorDate?.toIso8601String(),
    'lastSolved': lastSolvedDate?.toIso8601String(),
    'brokenValue': brokenStreakValue,
    'brokenAt': brokenAtDate?.toIso8601String(),
  };

  factory StreakData.fromJson(Map<String, dynamic> json) => StreakData(
    current: json['current'] as int? ?? 0,
    best: json['best'] as int? ?? 0,
    freezes: json['freezes'] as int? ?? 0,
    anchorDate: _parse(json['anchor']),
    lastSolvedDate: _parse(json['lastSolved']),
    brokenStreakValue: json['brokenValue'] as int?,
    brokenAtDate: _parse(json['brokenAt']),
  );

  static DateTime? _parse(Object? v) =>
      v is String ? DateTime.parse(v) : null;

  @override
  List<Object?> get props => [
    current,
    best,
    freezes,
    anchorDate,
    lastSolvedDate,
    brokenStreakValue,
    brokenAtDate,
  ];
}
