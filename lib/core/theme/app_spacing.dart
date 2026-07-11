/// Spacing scale (4pt grid from `design_tokens.md` §3.1) plus the small
/// icon↔label micro-gaps that recur across components (§3.2). Kept as named
/// constants so widgets never hardcode raw pixel gaps.
abstract final class AppSpacing {
  const AppSpacing._();

  // 4pt grid
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;

  // Structural card/dialog paddings (decisions collapses to these)
  static const double cardPad = 16;
  static const double dialogPadV = 26;
  static const double dialogPadH = 22;
  static const double sheetPadTop = 12;
  static const double sheetPadH = 20;
  static const double sheetPadBottom = 26;

  // Micro-gaps (icon ↔ label, chip internals)
  static const double gap5 = 5;
  static const double gap6 = 6;
  static const double gap7 = 7;
  static const double gap10 = 10;
  static const double gap11 = 11;
}
