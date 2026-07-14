import '../../../core/l10n/locale_keys.dart';

/// Ordered content for the fresh-install spotlight tour of the daily board:
/// what to teach and in what order, independent of where each target widget
/// actually sits on screen (that wiring — [GlobalKey]s and shapes — is
/// presentation's job).
enum DailyTourStep {
  topBar(LocaleKeys.dailyTourTopBarTitle, LocaleKeys.dailyTourTopBarBody),
  help(LocaleKeys.dailyTourHelpTitle, LocaleKeys.dailyTourHelpBody),
  hint(LocaleKeys.dailyTourHintTitle, LocaleKeys.dailyTourHintBody),
  mashqPill(LocaleKeys.dailyTourMashqTitle, LocaleKeys.dailyTourMashqBody),
  board(LocaleKeys.dailyTourBoardTitle, LocaleKeys.dailyTourBoardBody);

  const DailyTourStep(this.titleKey, this.bodyKey);

  final String titleKey;
  final String bodyKey;
}
