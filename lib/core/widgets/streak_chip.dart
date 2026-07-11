import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Streak/flame pill (component_spec (c)). The flame pulses (scale 1→1.12,
/// 1.6s, infinite) while the streak is active; at streak 0 the pulse STOPS and
/// the icon + value dim to `muted`/`text-3` (decisions §6).
class StreakChip extends StatefulWidget {
  const StreakChip({required this.streak, this.onTap, super.key});

  final int streak;
  final VoidCallback? onTap;

  @override
  State<StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<StreakChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _active => widget.streak > 0;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant StreakChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.streak > 0) != _active) _syncPulse();
  }

  void _syncPulse() {
    if (_active) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _active ? AppColors.fire : AppColors.muted;
    final valueColor = _active ? AppColors.text : AppColors.text3;

    final content = Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 11, 6), // asymmetric per spec
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.pillR,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.12).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Icon(AppIcons.flame, size: 16, color: iconColor),
          ),
          const SizedBox(width: 7),
          Text(
            '${widget.streak}',
            style: AppTextStyles.bodyStrong.copyWith(color: valueColor),
          ),
        ],
      ),
    );

    if (widget.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.pillR,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadii.pillR,
        child: content,
      ),
    );
  }
}
