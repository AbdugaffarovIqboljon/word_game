import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Semantic icon tokens (Lucide). Centralized so screens reference intent, not
/// raw icon getters, and so the icon set is swappable in one place.
abstract final class AppIcons {
  const AppIcons._();

  // Currencies & streak
  static const IconData coins = LucideIcons.coins;
  static const IconData gem = LucideIcons.gem;
  static const IconData flame = LucideIcons.flame;

  // Header / nav
  static const IconData settings = LucideIcons.settings;
  static const IconData hint = LucideIcons.lightbulb;
  static const IconData stats = LucideIcons.barChart3;
  static const IconData gift = LucideIcons.gift;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData close = LucideIcons.x;
  static const IconData practice = LucideIcons.dumbbell;
  static const IconData help = LucideIcons.helpCircle; // Qoidalar (rules) sheet

  // Keyboard action keys
  static const IconData enter = LucideIcons.cornerDownLeft; // ↵ submit key

  // Practice tiers
  static const IconData tierEasy = LucideIcons.star;
  static const IconData tierMedium = LucideIcons.zap;
  static const IconData tierHard = LucideIcons.flame;

  // Share
  static const IconData share = LucideIcons.share2;
  static const IconData telegram = LucideIcons.send;
  static const IconData stories = LucideIcons.image;
  static const IconData copy = LucideIcons.copy;

  // Gameplay / results
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData clock = LucideIcons.clock;
  static const IconData check = LucideIcons.check;

  // Hints
  static const IconData reveal = LucideIcons.eye;
  static const IconData clean = LucideIcons.eraser;
  static const IconData dictionary = LucideIcons.bookOpen;
  static const IconData watchAd = LucideIcons.tv;
  static const IconData lock = LucideIcons.lock;

  // Streak / freeze
  static const IconData snowflake = LucideIcons.snowflake;
  static const IconData plus = LucideIcons.plus;
  static const IconData refresh = LucideIcons.refreshCw;

  // Shop
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData package = LucideIcons.package;
  static const IconData shoppingBag = LucideIcons.shoppingBag;

  // Settings
  static const IconData sound = LucideIcons.volume2;
  static const IconData haptics = LucideIcons.zap;
  static const IconData notifications = LucideIcons.bell;
  static const IconData language = LucideIcons.languages;
  static const IconData info = LucideIcons.info;
}
