import 'package:flutter/painting.dart';

import '../../theme/app_colors.dart';
import 'tile_skin.dart';
import 'tile_state.dart';

/// Resolved paint for a tile state — shared by the animated [LetterTile] and the
/// static recap/fail/onboarding boards so the 5-state palette lives in one place.
class TileVisuals {
  const TileVisuals(this.background, this.border, this.foreground);

  final Color background;
  final Border? border;
  final Color foreground;
}

/// Resolves the paint for [state], applying [skin] to the correct/present
/// states (empty/typing/absent are never skinned). Defaults to the base skin.
TileVisuals tileVisualsFor(TileState state, {TileSkin skin = TileSkin.standart}) =>
    switch (state) {
      TileState.empty => const TileVisuals(
        Color(0x00000000),
        Border.fromBorderSide(
          BorderSide(color: AppColors.tileEmptyBorder, width: 2),
        ),
        AppColors.text,
      ),
      TileState.typing => const TileVisuals(
        AppColors.tileFilledBg,
        Border.fromBorderSide(
          BorderSide(color: AppColors.tileFilledBorder, width: 2),
        ),
        AppColors.white,
      ),
      TileState.absent => const TileVisuals(
        AppColors.tileAbsentBg,
        null,
        AppColors.tileAbsentFg,
      ),
      TileState.present => TileVisuals(skin.present, null, skin.onPresent),
      TileState.correct => TileVisuals(skin.correct, null, skin.onCorrect),
      TileState.prefill => TileVisuals(skin.present, null, skin.onPresent),
    };
