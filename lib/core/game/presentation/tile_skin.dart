import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// The procedural board-area ambiance a skin paints behind the grid (WS4).
/// Rendered by `SkinPatternPainter`; kept as a plain enum so [TileSkin] stays a
/// pure data class with no widget/paint dependencies.
enum SkinPattern {
  /// Standart — no ambiance.
  none,

  /// Milliy — a girih-style interlaced geometric lattice.
  girih,

  /// Neon — a faint orthogonal grid glow.
  neonGrid,

  /// Oltin — a soft radial shimmer with corner flourishes.
  oltinShimmer,
}

/// The full visual identity of a skin (WS4): the skinnable tile colors (only
/// correct/present change — empty/typing/absent stay on the base palette), plus
/// the board-area [pattern] and the [accent] tint used on the context header
/// chip and the Mashq pill.
class TileSkin {
  const TileSkin({
    required this.id,
    required this.correct,
    required this.onCorrect,
    required this.present,
    required this.onPresent,
    this.pattern = SkinPattern.none,
    this.accent = AppColors.textSub,
  });

  final String id;
  final Color correct;
  final Color onCorrect;
  final Color present;
  final Color onPresent;

  /// Procedural background painted behind the board for this skin.
  final SkinPattern pattern;

  /// Ambient accent applied to the context header chip and Mashq pill. Standart
  /// keeps the neutral default so it reads unchanged.
  final Color accent;

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
      pattern: SkinPattern.girih,
      accent: Color(0xFF3FB0A6),
    ),
    'neon': TileSkin(
      id: 'neon',
      correct: Color(0xFF2BE38A),
      onCorrect: AppColors.bg,
      present: Color(0xFF7BC8FF),
      onPresent: AppColors.bg,
      pattern: SkinPattern.neonGrid,
      accent: Color(0xFF2BE38A),
    ),
    'oltin': TileSkin(
      id: 'oltin',
      correct: AppColors.goldBright,
      onCorrect: AppColors.onGold,
      present: Color(0xFFC2952B),
      onPresent: AppColors.bg,
      pattern: SkinPattern.oltinShimmer,
      accent: AppColors.goldBright,
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
