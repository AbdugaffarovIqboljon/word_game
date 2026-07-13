import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/nav_header.dart';
import '../../shop/domain/purchase_gateway.dart';
import '../../streak/data/streak_reminder_scheduler.dart';
import '../data/settings_service.dart';

/// Settings (decisions §8): language rows (uz-Latn active, others disabled for
/// v1), real sound/haptics/notifications toggles, remove-ads → shop, restore,
/// version footer.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = sl<SettingsService>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavHeader(title: LocaleKeys.settingsNavTitle.tr()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _SectionLabel(text: LocaleKeys.settingsLanguage.tr()),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _LanguageRow(
                          label: LocaleKeys.settingsLangUzLatn.tr(),
                          active: true,
                        ),
                        const _RowDivider(),
                        _LanguageRow(
                          label: LocaleKeys.settingsLangRu.tr(),
                          active: false,
                        ),
                        const _RowDivider(),
                        _LanguageRow(
                          label: LocaleKeys.settingsLangUzCyrl.tr(),
                          active: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ToggleRow(
                          icon: AppIcons.sound,
                          label: LocaleKeys.settingsSound.tr(),
                          value: settings.sound,
                          onChanged: settings.setSound,
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          icon: AppIcons.haptics,
                          label: LocaleKeys.settingsHaptics.tr(),
                          value: settings.haptics,
                          onChanged: settings.setHaptics,
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          icon: AppIcons.notifications,
                          label: LocaleKeys.settingsNotifications.tr(),
                          value: settings.notifications,
                          onChanged: (v) => _toggleNotifications(context, v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: AppIcons.help,
                          label: LocaleKeys.settingsReplayTutorial.tr(),
                          onTap: () => context.push(
                            AppRoutes.tutorial,
                            extra: false,
                          ),
                        ),
                        const _RowDivider(),
                        _ActionRow(
                          icon: AppIcons.shieldCheck,
                          label: LocaleKeys.settingsRemoveAds.tr(),
                          onTap: () => context.push(AppRoutes.shop),
                        ),
                        const _RowDivider(),
                        _ActionRow(
                          icon: AppIcons.refresh,
                          label: LocaleKeys.settingsRestore.tr(),
                          onTap: () => _restore(context),
                        ),
                        const _RowDivider(),
                        _ActionRow(
                          icon: AppIcons.info,
                          // uz-Latn only in v1; the attribution copy is fixed.
                          label: 'Maʼlumotlar manbasi',
                          onTap: () => _showAttribution(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      LocaleKeys.settingsVersion.tr(namedArgs: {'version': '1.0.0'}),
                      style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    await sl<PurchaseGateway>().restore();
  }

  /// Manual notifications toggle. Enabling requests the OS permission; if the OS
  /// denies it, guide the user to system settings (WS2).
  Future<void> _toggleNotifications(BuildContext context, bool enabled) async {
    final settings = sl<SettingsService>();
    final scheduler = sl<StreakReminderScheduler>();
    settings.setNotifications(enabled);
    if (!enabled) {
      await scheduler.onNotificationsToggled(false);
      return;
    }
    final granted = await scheduler.requestAndSchedule();
    if (!granted && context.mounted) _showNotifDenied(context);
  }

  void _showNotifDenied(BuildContext context) {
    showAppDialog<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.settingsNotifDeniedTitle.tr(),
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.settingsNotifDeniedBody.tr(),
            style: AppTextStyles.body.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                LocaleKeys.settingsNotifDeniedCta.tr(),
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.gem),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CC BY-SA attribution for the bundled word data (assets/dictionary/README.md).
  void _showAttribution(BuildContext context) {
    showAppDialog<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Maʼlumotlar manbasi', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Text(
            'Soʻz maʼlumotlari Oʻzbek Vikipediyasidan (uz.wikipedia.org, '
            'CC BY-SA 4.0) va MUNIS oʻzbek lotin hunspell lugʻatidan (CC0) '
            'olingan. Batafsil: tool/corpus/SOURCES.md.',
            style: AppTextStyles.body.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Yopish',
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.gem),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(), style: AppTextStyles.micro),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    color: AppColors.border,
    indent: 16,
    endIndent: 16,
  );
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(
            AppIcons.language,
            size: 18,
            color: active ? AppColors.text2 : AppColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: active ? AppColors.text : AppColors.text3,
              ),
            ),
          ),
          if (active)
            const Icon(AppIcons.check, size: 18, color: AppColors.successBright)
          else
            Text(
              LocaleKeys.settingsComingSoon.tr(),
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final ValueListenable<bool> value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.text2),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.text))),
          ValueListenableBuilder<bool>(
            valueListenable: value,
            builder: (context, on, _) => Switch(
              value: on,
              onChanged: onChanged,
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.correct,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.text2),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.text))),
            const Icon(AppIcons.chevronRight, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
