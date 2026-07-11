import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// The skinnable colors of a board tile — only the correct/present states change
/// with a skin; empty/typing/absent stay on the base palette.
class TileSkin {
  const TileSkin({
    required this.id,
    required this.correct,
    required this.onCorrect,
    required this.present,
    required this.onPresent,
  });

  final String id;
  final Color correct;
  final Color onCorrect;
  final Color present;
  final Color onPresent;

  static const standart = TileSkin(
    id: 'standart',
    correct: AppColors.correct,
    onCorrect: AppColors.onCorrect,
    present: AppColors.present,
    onPresent: AppColors.onPresent,
  );

  static const _catalog = <String, TileSkin>{
    'standart': standart,
    'milliy': TileSkin(
      id: 'milliy',
      correct: Color(0xFF2E8B8B),
      onCorrect: AppColors.white,
      present: Color(0xFFC77B4E),
      onPresent: AppColors.bg,
    ),
    'neon': TileSkin(
      id: 'neon',
      correct: Color(0xFF2BE38A),
      onCorrect: AppColors.bg,
      present: Color(0xFF7BC8FF),
      onPresent: AppColors.bg,
    ),
    'oltin': TileSkin(
      id: 'oltin',
      correct: AppColors.goldBright,
      onCorrect: AppColors.onGold,
      present: Color(0xFFC2952B),
      onPresent: AppColors.bg,
    ),
  };

  static TileSkin byId(String id) => _catalog[id] ?? standart;
}

/// Provides the active [TileSkin] to the board subtree so tiles read it from
/// context — keeping the core board widgets decoupled from the shop's
/// skin-selection service (the screen wraps the board in this scope).
class TileSkinScope extends InheritedWidget {
  const TileSkinScope({required this.skin, required super.child, super.key});

  final TileSkin skin;

  static TileSkin of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TileSkinScope>();
    return scope?.skin ?? TileSkin.standart;
  }

  @override
  bool updateShouldNotify(TileSkinScope oldWidget) => oldWidget.skin.id != skin.id;
}
