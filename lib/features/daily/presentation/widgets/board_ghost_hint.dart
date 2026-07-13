import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/game/presentation/board_controller.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_text_styles.dart';

/// First-run ghost prompt centered over the empty board (30% opacity). Shown
/// only while the very first tile is empty and untouched — it disappears on the
/// first keypress (cursor advances past 0,0).
///
/// On the user's first-ever real daily board [firstGame] swaps the copy for the
/// warmer "Istalgan soʻzdan boshlang — ranglar yoʻl koʻrsatadi" affordance (WS1).
class BoardGhostHint extends StatelessWidget {
  const BoardGhostHint({required this.cursor, this.firstGame = false, super.key});

  final ValueListenable<BoardCursor> cursor;
  final bool firstGame;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BoardCursor>(
      valueListenable: cursor,
      builder: (context, c, _) {
        final show = c.row == 0 && c.col == 0;
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: show ? 0.3 : 0,
            duration: const Duration(milliseconds: 180),
            child: Text(
              (firstGame
                      ? LocaleKeys.dailyGhostHintFirst
                      : LocaleKeys.dailyGhostHint)
                  .tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong,
            ),
          ),
        );
      },
    );
  }
}
