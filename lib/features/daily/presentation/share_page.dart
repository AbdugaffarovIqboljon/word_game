import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/dashed_border_box.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../domain/daily_share_data.dart';

/// Result / Share modal (screen_inventory §2). Emoji-grid preview generated from
/// game state, Telegram-first share ordering, coin breakdown, cross-promo slot.
class SharePage extends StatelessWidget {
  const SharePage({required this.data, super.key});

  final DailyShareData? data;

  String _shareText(DailyShareData d) {
    final header = LocaleKeys.shareCardHeader.tr(
      namedArgs: {
        'puzzle': '${d.puzzleNumber}',
        'attempts': d.attemptsLabel,
        'max': '${d.maxAttempts}',
        'streak': '${d.streak}',
      },
    );
    return '$header\n\n${d.emojiGrid}\n\n${LocaleKeys.commonDomain.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: d == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _NavBar(onClose: () => context.pop()),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        children: [
                          ShareEmojiCard(data: d),
                          const SizedBox(height: 8),
                          Text(
                            LocaleKeys.shareTelegramCaption.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: LocaleKeys.shareTelegram.tr(),
                            variant: PrimaryButtonVariant.telegram,
                            icon: AppIcons.telegram,
                            onPressed: () => SharePlus.instance.share(
                              ShareParams(text: _shareText(d)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  label: LocaleKeys.shareStories.tr(),
                                  icon: AppIcons.stories,
                                  onPressed: () => SharePlus.instance.share(
                                    ShareParams(text: _shareText(d)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SecondaryButton(
                                  label: LocaleKeys.shareCopy.tr(),
                                  icon: AppIcons.copy,
                                  onPressed: () => _copy(context, _shareText(d)),
                                ),
                              ),
                            ],
                          ),
                          if (d.reward != null) ...[
                            const SizedBox(height: 20),
                            CoinBreakdownCard(data: d),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlineButton(
                              label: LocaleKeys.sharePracticeCta.tr(),
                              icon: AppIcons.practice,
                              onPressed: () => context.push(AppRoutes.practice),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DashedBorderBox(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                LocaleKeys.shareCrossPromo.tr(),
                                style: AppTextStyles.micro,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.shareCopied.tr())),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(LocaleKeys.shareNavTitle.tr(), style: AppTextStyles.navTitle),
          Align(
            alignment: Alignment.centerRight,
            child: AppIconButton(
              icon: AppIcons.close,
              iconColor: AppColors.text3,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Telegram-style emoji preview card (component_spec (c)).
class ShareEmojiCard extends StatelessWidget {
  const ShareEmojiCard({required this.data, super.key});

  final DailyShareData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.popover,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            LocaleKeys.shareCardHeader.tr(
              namedArgs: {
                'puzzle': '${data.puzzleNumber}',
                'attempts': data.attemptsLabel,
                'max': '${data.maxAttempts}',
                'streak': '${data.streak}',
              },
            ),
            style: AppTextStyles.bodyStrong,
          ),
          const SizedBox(height: 12),
          Text(
            data.emojiGrid,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, height: 1.34, letterSpacing: 3),
          ),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.commonDomain.tr(),
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Base + speed + streak = total coin breakdown (screen_inventory §2).
class CoinBreakdownCard extends StatelessWidget {
  const CoinBreakdownCard({required this.data, super.key});

  final DailyShareData data;

  @override
  Widget build(BuildContext context) {
    final reward = data.reward!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          BreakdownRow(label: LocaleKeys.shareBreakdownBase.tr(), value: reward.base),
          const SizedBox(height: 11),
          BreakdownRow(label: LocaleKeys.shareBreakdownSpeed.tr(), value: reward.speed),
          const SizedBox(height: 11),
          BreakdownRow(
            label: LocaleKeys.shareBreakdownStreak.tr(),
            value: reward.streakBonus,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          BreakdownRow(
            label: LocaleKeys.shareBreakdownTotal.tr(),
            value: reward.total,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasized
        ? AppTextStyles.bodyStrong
        : AppTextStyles.body.copyWith(color: AppColors.textSub);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Row(
          children: [
            const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
            const SizedBox(width: 6),
            Text(
              '+$value',
              style: AppTextStyles.bodyStrong.copyWith(
                color: emphasized ? AppColors.coin : AppColors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
