import 'package:flutter/material.dart';

import '../../../theme/app_radii.dart';
import '../../../theme/app_text_styles.dart';
import '../tile_skin.dart';
import '../tile_state.dart';
import '../tile_visuals.dart';

/// A non-animated tile face for a given [TileData]/size. Used by the animated
/// [LetterTile] (as its face) and by the recap/fail/onboarding static boards.
class StaticTile extends StatelessWidget {
  const StaticTile({required this.data, required this.size, super.key});

  final TileData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visuals = tileVisualsFor(data.state, skin: TileSkinScope.of(context));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: visuals.background,
        border: visuals.border,
        borderRadius: AppRadii.tileR,
      ),
      child: data.letter == null
          ? null
          : Text(
              data.letter!.toUpperCase(),
              style: AppTextStyles.tile(size / 2, color: visuals.foreground),
            ),
    );
  }
}
