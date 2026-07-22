import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Mystery theme hint ("🔮 Mavzu: {theme}") shown above the board in daily,
/// practice and bonus games.
///
/// Enters with a soft scale+fade, holds for [initialSeconds], then collapses
/// into a small chip docked next to the board context header. Tapping the chip
/// calls [onReexpand] — the page charges coins (or a rewarded ad) through the
/// atomic pay→effect→refund pattern and resolves `true` when paid — and the
/// card re-expands for [reexpandSeconds].
///
/// The free auto-show plays only when [autoShow] is true (daily persists this
/// per puzzle in the board snapshot; practice/bonus re-show per round via
/// [roundNonce]). [onAutoShown] fires exactly when the free show starts.
class PracticeThemeBanner extends StatefulWidget {
  const PracticeThemeBanner({
    required this.theme,
    required this.roundNonce,
    required this.reexpandCost,
    required this.onReexpand,
    this.initialSeconds = 5,
    this.reexpandSeconds = 5,
    this.autoShow = true,
    this.onAutoShown,
    this.autoShowGate,
    super.key,
  });

  final String? theme;
  final int roundNonce;
  final int reexpandCost;

  /// Optional gate (WS3): when supplied, the free auto-show waits until this
  /// listenable reads `true` before starting its timer — so it never runs (nor
  /// consumes the free-show flag via [onAutoShown]) while a first-run rules/
  /// coach surface is covering the board. Null on practice/bonus, which have no
  /// competing first-run overlays and auto-show immediately.
  final ValueListenable<bool>? autoShowGate;

  /// Runs the atomic re-expand purchase. The banner hands its own re-show
  /// effect in as `show`, so the page/cubit can do pay → show → refund-on-fail
  /// without ever charging for a card that could not appear.
  final Future<bool> Function(Future<bool> Function() show) onReexpand;
  final int initialSeconds;
  final int reexpandSeconds;

  /// Whether this round still owes the player the free auto-show. When false
  /// (e.g. restored daily board after an app restart) the banner starts
  /// collapsed as the chip.
  final bool autoShow;
  final VoidCallback? onAutoShown;

  @override
  State<PracticeThemeBanner> createState() => _PracticeThemeBannerState();
}

class _PracticeThemeBannerState extends State<PracticeThemeBanner>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 400);

  // Constructed eagerly in initState (not lazily) so the ticker is always
  // created while the element is active — a gated-shut banner that is disposed
  // before it ever animates must never build its ticker inside dispose().
  late final AnimationController _controller;
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.94, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  /// True while the expanded card is (or is animating) on screen.
  final ValueNotifier<bool> _expanded = ValueNotifier(false);

  Timer? _holdTimer;
  bool _reexpandInFlight = false;
  bool _autoShown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _transitionDuration);
    _maybeAutoShow();
  }

  @override
  void didUpdateWidget(covariant PracticeThemeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roundNonce != oldWidget.roundNonce) {
      // New practice/bonus round — allow a fresh auto-show.
      _autoShown = false;
      _maybeAutoShow();
    }
  }

  /// Starts the free auto-show once — immediately when ungated, or when the
  /// gate opens (WS3). The gate is consulted live so a first-run rules/coach
  /// surface defers both the timer and the [onAutoShown] flag consumption.
  void _maybeAutoShow() {
    if (_autoShown || widget.theme == null || !widget.autoShow) return;
    final gate = widget.autoShowGate;
    if (gate == null || gate.value) {
      _startAutoShow();
    } else {
      gate.addListener(_onGateChanged);
    }
  }

  void _onGateChanged() {
    if (!mounted) return;
    if (widget.autoShowGate?.value ?? true) {
      widget.autoShowGate?.removeListener(_onGateChanged);
      _startAutoShow();
    }
  }

  void _startAutoShow() {
    if (_autoShown) return;
    _autoShown = true;
    widget.onAutoShown?.call();
    _play(holdSeconds: widget.initialSeconds);
  }

  void _play({required int holdSeconds}) {
    _holdTimer?.cancel();
    _expanded.value = true;
    _controller.forward(from: 0);
    _holdTimer = Timer(Duration(seconds: holdSeconds), () {
      if (!mounted) return;
      _controller.reverse().whenCompleteOrCancel(() {
        if (mounted) _expanded.value = false;
      });
    });
  }

  /// Re-expands the card after a successful charge; returned future backs the
  /// page's atomic pay→effect→refund contract (`false` triggers its refund).
  Future<bool> _show() async {
    if (!mounted) return false;
    _play(holdSeconds: widget.reexpandSeconds);
    return true;
  }

  Future<void> _onChipTap() async {
    if (_reexpandInFlight) return;
    _reexpandInFlight = true;
    try {
      await widget.onReexpand(_show);
    } finally {
      _reexpandInFlight = false;
    }
  }

  @override
  void dispose() {
    widget.autoShowGate?.removeListener(_onGateChanged);
    _holdTimer?.cancel();
    _controller.dispose();
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (theme == null) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<bool>(
        valueListenable: _expanded,
        builder: (context, expanded, _) {
          if (!expanded) {
            return ThemeHintChip(
              price: widget.reexpandCost,
              onTap: _onChipTap,
            );
          }
          return FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(scale: _scale, child: ThemeHintCard(theme: theme)),
          );
        },
      ),
    );
  }
}

/// The mystery clue card: "🔮 Mavzu: {theme}".
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

/// Collapsed state: a small docked chip (🔮 + price) that re-expands the card
/// for coins when tapped.
class ThemeHintChip extends StatelessWidget {
  const ThemeHintChip({required this.price, required this.onTap, super.key});

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
                const Icon(AppIcons.coins, size: 12, color: AppColors.coin),
                const SizedBox(width: 3),
                Text(
                  '$price',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
