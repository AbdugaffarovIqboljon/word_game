import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'primary_button.dart';

/// Cutout shape drawn around a [SpotlightStep]'s target.
enum SpotlightShape { circle, roundedRect }

/// One stop of a [SpotlightTour]: the widget to highlight (via [targetKey])
/// and the copy shown in its callout. Screen-agnostic — any feature can build
/// its own ordered [SpotlightStep] list against its own [GlobalKey]s.
@immutable
class SpotlightStep {
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.shape = SpotlightShape.roundedRect,
    this.outset = 8,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final SpotlightShape shape;

  /// Extra margin (px) added around the target's measured bounds.
  final double outset;
}

/// Drives step progression for a [SpotlightTour]: `value` is the current step
/// index, or -1 while idle/finished/skipped. Create in `initState`, dispose in
/// `dispose`; call [start] once the caller decides the tour should run.
class SpotlightTourController extends ValueNotifier<int> {
  SpotlightTourController({required this.stepCount}) : super(-1);

  final int stepCount;

  bool get isActive => value >= 0;

  /// Begins the tour at its first step (a no-op if there is nothing to show).
  void start() {
    if (stepCount > 0) value = 0;
  }

  /// Advances to the next step, finishing the tour from the last one.
  void next() {
    if (!isActive) return;
    value = value + 1 >= stepCount ? -1 : value + 1;
  }

  /// Dismisses the tour immediately, from any step.
  void skip() => value = -1;
}

/// A full-page sequential spotlight tour: a dark scrim covering the screen
/// except a cutout around the current step's target — measured live from its
/// [GlobalKey]/[RenderBox], never hardcoded — paired with a callout bubble
/// showing the step's title/description and Next/Skip actions.
///
/// Generic and reusable: drop it as the top-most child of a page's [Stack]
/// and drive it with a [SpotlightTourController]. Target layout may not be
/// ready on the frame the tour starts (e.g. a key's context is still null),
/// so measurement retries for a bounded number of frames rather than assuming
/// the first attempt succeeds.
class SpotlightTour extends StatefulWidget {
  const SpotlightTour(
      {required this.controller, required this.steps, super.key});

  final SpotlightTourController controller;
  final List<SpotlightStep> steps;

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour>
    with SingleTickerProviderStateMixin {
  static const int _maxMeasureAttempts = 12;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  Rect? _targetRect;
  int _measureAttempts = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStepChanged);
    if (widget.controller.isActive) _measure();
  }

  @override
  void didUpdateWidget(covariant SpotlightTour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStepChanged);
      widget.controller.addListener(_onStepChanged);
    }
  }

  void _onStepChanged() {
    if (!mounted) return;
    setState(() => _targetRect = null);
    if (widget.controller.isActive) _measure();
  }

  void _measure() {
    _measureAttempts = 0;
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.isActive) return;
      final key = widget.steps[widget.controller.value].targetKey;
      final box = key.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        setState(() => _targetRect = box.localToGlobal(Offset.zero) & box.size);
        return;
      }
      // The target's layout may not have run yet on the first few frames —
      // retry for a bounded number of frames instead of assuming it exists.
      if (++_measureAttempts < _maxMeasureAttempts) _scheduleMeasure();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStepChanged);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller,
      builder: (context, index, _) {
        if (index < 0 || index >= widget.steps.length) {
          return const SizedBox.shrink();
        }
        final step = widget.steps[index];
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // swallow taps to the app underneath during the tour
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _SpotlightPainter(
                  rect: _targetRect,
                  shape: step.shape,
                  outset: step.outset,
                  ringColor: Color.lerp(
                      AppColors.border, AppColors.gem, _pulse.value)!,
                ),
                child: SpotlightCallout(
                  targetRect: _targetRect,
                  title: step.title,
                  description: step.description,
                  isLastStep: index == widget.steps.length - 1,
                  onNext: widget.controller.next,
                  onSkip: widget.controller.skip,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dark scrim over the full screen with a cutout (circle or rounded-rect)
/// around [rect], ringed with the same pulsing highlight used elsewhere in
/// the app's coach marks.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.rect,
    required this.shape,
    required this.outset,
    required this.ringColor,
  });

  final Rect? rect;
  final SpotlightShape shape;
  final double outset;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final scrimPaint = Paint()..color = AppColors.bg.withValues(alpha: 0.88);
    final target = rect?.inflate(outset);

    if (target == null) {
      canvas.drawRect(screen, scrimPaint);
      return;
    }

    final holePath = shape == SpotlightShape.circle
        ? (Path()..addOval(target))
        : (Path()
          ..addRRect(RRect.fromRectAndRadius(
              target, const Radius.circular(AppRadii.card))));
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(screen),
      holePath,
    );
    canvas.drawPath(scrimPath, scrimPaint);
    canvas.drawPath(
      holePath,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.rect != rect ||
      old.shape != shape ||
      old.outset != outset ||
      old.ringColor != ringColor;
}

/// The title/description callout anchored near [targetRect] (below it, or
/// above when there isn't room underneath), plus the Next/Skip actions. Falls
/// back to a centered position while [targetRect] is still unmeasured.
class SpotlightCallout extends StatelessWidget {
  const SpotlightCallout({
    required this.targetRect,
    required this.title,
    required this.description,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final Rect? targetRect;
  final String title;
  final String description;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const double _margin = 16;
  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final rect = targetRect;
    final placeBelow = rect == null || rect.center.dy < screenHeight * 0.55;

    return Stack(
      children: [
        Positioned(
          left: _margin,
          right: _margin,
          top: placeBelow ? (rect?.bottom ?? screenHeight * 0.42) + _gap : null,
          bottom: placeBelow ? null : screenHeight - (rect.top - _gap),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceModal,
                borderRadius: AppRadii.cardR,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(description, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: (isLastStep
                            ? LocaleKeys.commonOk
                            : LocaleKeys.commonNext)
                        .tr(),
                    onPressed: onNext,
                    height: 44,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: _margin,
          top: media.padding.top + 8,
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              LocaleKeys.commonSkip.tr(),
              style: AppTextStyles.body.copyWith(color: AppColors.text3),
            ),
          ),
        ),
      ],
    );
  }
}
