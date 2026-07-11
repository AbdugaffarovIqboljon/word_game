import 'package:flutter/painting.dart';

/// Corner-radius tokens. Reconciled per `decisions.md` §3:
/// keyboard key = 7px, ALL cards = 16px, dialog = 22px.
abstract final class AppRadii {
  const AppRadii._();

  static const double tile = 6;
  static const double key = 7; // decisions §3 (live component, not the 8px legend)
  static const double iconButton = 10;
  static const double chip = 12;
  static const double button = 14; // primary CTA
  static const double card = 16; // decisions §3 — ALL cards
  static const double pill = 20; // counter chips
  static const double dialog = 22; // decisions §3 (radiusDialog)
  static const double sheet = 28;

  static const BorderRadius tileR = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius keyR = BorderRadius.all(Radius.circular(key));
  static const BorderRadius iconButtonR =
      BorderRadius.all(Radius.circular(iconButton));
  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius buttonR = BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius dialogR = BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius sheetTopR = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
