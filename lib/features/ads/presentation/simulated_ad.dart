import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// A stand-in full-screen "rewarded ad" shown by the debug ad fake so device
/// testing exercises the real ad flow (watch → then reward) instead of granting
/// coins instantly. In release builds the real AdMob SDK shows the actual ad, so
/// this is never used there.
Future<void> showSimulatedRewardedAd(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'ad',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => const _SimulatedAd(),
  );
}

class _SimulatedAd extends StatefulWidget {
  const _SimulatedAd();

  @override
  State<_SimulatedAd> createState() => _SimulatedAdState();
}

class _SimulatedAdState extends State<_SimulatedAd> {
  static const int _seconds = 3;
  int _left = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TEST REKLAMA',
                  style: AppTextStyles.micro.copyWith(color: AppColors.textSub),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.coin,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.coins, size: 44, color: AppColors.onGold),
                ),
                const SizedBox(height: 24),
                Text(
                  done ? 'Reklama tugadi' : 'Reklama koʻrsatilmoqda…',
                  style: AppTextStyles.title.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  done ? 'Mukofotingizni oling' : '$_left',
                  style: AppTextStyles.display.copyWith(color: AppColors.coin),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: done ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !done,
                    child: PrimaryButton(
                      label: 'Mukofotni olish',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
