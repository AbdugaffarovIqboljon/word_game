import 'package:flutter/widgets.dart';

/// Locale configuration. uz-Latn is the only launch locale; ru and uz-Cyrl are
/// declared as supported so the structure is ready (Settings shows them
/// disabled-for-v1). Adding a translation is dropping a new JSON in
/// `assets/translations/` and enabling its Settings row — no code change here
/// beyond appending to [supported].
abstract final class AppLocales {
  const AppLocales._();

  static const Locale uzLatn = Locale('uz');
  static const Locale ru = Locale('ru');
  static const Locale uzCyrl = Locale('uz', 'Cyrl');

  static const List<Locale> supported = [uzLatn];

  static const Locale start = uzLatn;
  static const Locale fallback = uzLatn;

  static const String path = 'assets/translations';
}
