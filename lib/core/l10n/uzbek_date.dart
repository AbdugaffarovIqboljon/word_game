/// Localized date line for the daily-board context header, e.g.
/// `10-iyul, payshanba`. uz-Latn is the only active locale in v1 (ru & uz-Cyrl
/// are present-but-disabled — see settings), so the names are held here rather
/// than routed through `intl`, which ships no `uz` symbol set.
abstract final class UzbekDate {
  const UzbekDate._();

  static const List<String> _months = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];

  /// [DateTime.weekday] is 1 (Monday) … 7 (Sunday).
  static const List<String> _weekdays = [
    'dushanba',
    'seshanba',
    'chorshanba',
    'payshanba',
    'juma',
    'shanba',
    'yakshanba',
  ];

  /// Formats [date] (a date-only instant) as `10-iyul, payshanba`.
  static String format(DateTime date) {
    final month = _months[date.month - 1];
    final weekday = _weekdays[date.weekday - 1];
    return '${date.day}-$month, $weekday';
  }
}
