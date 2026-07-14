import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/game/presentation/widgets/invalid_word_toast.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Cryptic theme/category clue banner shown above the practice board.
///
/// Auto-plays fade-in → hold → fade-out once per round (keyed by
/// [roundNonce]). Once it fades out, a small sparkle affordance takes its
/// place; tapping it calls [onRecall] (which should charge coins) and, on
/// success, replays the same animation.
class PracticeThemeBanner extends StatefulWidget {
  const PracticeThemeBanner({
    required this.theme,
    required this.roundNonce,
    required this.recallPrice,
    required this.onRecall,
    super.key,
  });

  final String? theme;
  final int roundNonce;
  final int recallPrice;
  final Future<bool> Function() onRecall;

  @override
  State<PracticeThemeBanner> createState() => _PracticeThemeBannerState();
}

class _PracticeThemeBannerState extends State<PracticeThemeBanner>
    with SingleTickerProviderStateMixin {
  static const _fadeDuration = Duration(milliseconds: 400);
  static const _holdDuration = Duration(seconds: 7);

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: _fadeDuration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fadeController,
    curve: Curves.easeInOut,
  );
  final ValueNotifier<bool> _showRecallAffordance = ValueNotifier(false);

  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    if (widget.theme != null) _play();
  }

  @override
  void didUpdateWidget(covariant PracticeThemeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roundNonce != oldWidget.roundNonce && widget.theme != null) {
      _play();
    }
  }

  void _play() {
    _holdTimer?.cancel();
    _showRecallAffordance.value = false;
    _fadeController.forward(from: 0);
    _holdTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      _fadeController.reverse().whenCompleteOrCancel(() {
        if (mounted) _showRecallAffordance.value = true;
      });
    });
  }

  Future<void> _onRecallTap() async {
    final ok = await widget.onRecall();
    if (!mounted) return;
    if (!ok) {
      InvalidWordToast.show(
        context,
        message: LocaleKeys.practiceThemeInsufficient.tr(),
        topOffset: 90,
      );
      return;
    }
    _play();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fadeController.dispose();
    _showRecallAffordance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (theme == null) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<bool>(
        valueListenable: _showRecallAffordance,
        builder: (context, showRecall, _) {
          if (showRecall) {
            return ThemeRecallAffordance(
              price: widget.recallPrice,
              onTap: _onRecallTap,
            );
          }
          return FadeTransition(
            opacity: _opacity,
            child: ThemeHintCard(theme: theme),
          );
        },
      ),
    );
  }
}

/// The mystical clue card: "Bu soʻz — {theme} mavzusida".
class ThemeHintCard extends StatelessWidget {
  const ThemeHintCard({required this.theme, super.key});

  final String theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.gem.withValues(alpha: 0.12),
        borderRadius: AppRadii.chipR,
        border: Border.all(color: AppColors.gem.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.sparkles, size: 16, color: AppColors.gem),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              LocaleKeys.practiceThemeHint.tr(namedArgs: {'theme': theme}),
              style: AppTextStyles.caption.copyWith(color: AppColors.text2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tappable sparkle + price pill that recalls the faded theme banner.
class ThemeRecallAffordance extends StatelessWidget {
  const ThemeRecallAffordance({
    required this.price,
    required this.onTap,
    super.key,
  });

  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillR,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadii.pillR,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.sparkles, size: 14, color: AppColors.gem),
                const SizedBox(width: 6),
                Icon(AppIcons.coins, size: 12, color: AppColors.coin),
                const SizedBox(width: 3),
                Text('$price', style: AppTextStyles.caption.copyWith(color: AppColors.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
