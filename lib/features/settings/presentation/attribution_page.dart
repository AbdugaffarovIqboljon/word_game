import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/nav_header.dart';

/// Full-screen data-source attribution (WS6). Replaces the old dialog: a proper
/// pushed page reached from the Settings "Maʼlumotlar manbasi" row, crediting the
/// open sources with tappable links, and free of any internal repo path.
class AttributionPage extends StatelessWidget {
  const AttributionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const NavHeader(title: 'Maʼlumotlar manbasi'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text(
                    'Soʻz Jangidagi soʻz maʼlumotlari ochiq (open-source) '
                    'manbalardan olingan va oʻyin uchun moslashtirilgan.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.text2,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SourceCard(
                    title: 'Oʻzbek Vikipediyasi',
                    body: 'Soʻzlarning keng tarqalganligi (chastotasi) Oʻzbek '
                        'Vikipediya matnlaridan hisoblab olingan.',
                    linkLabel: 'uz.wikipedia.org',
                    linkUrl: 'https://uz.wikipedia.org',
                    licenseLabel: 'Litsenziya: CC BY-SA 4.0',
                    licenseUrl:
                        'https://creativecommons.org/licenses/by-sa/4.0/',
                  ),
                  const SizedBox(height: 14),
                  const _SourceCard(
                    title: 'MUNIS oʻzbek lotin hunspell lugʻati',
                    body: 'Haqiqiy oʻzbekcha soʻzlar roʻyxati shu imlo '
                        'lugʻatiga asoslangan.',
                    linkLabel: 'CC0 (jamoat mulki)',
                    linkUrl:
                        'https://creativecommons.org/publicdomain/zero/1.0/',
                    licenseLabel: 'Litsenziya: CC0',
                    licenseUrl:
                        'https://creativecommons.org/publicdomain/zero/1.0/',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Soʻz maʼlumotlari CC BY-SA 4.0 shartlari asosida '
                    'moslashtirilgan.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSub,
                      height: 1.4,
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
}

/// One credited source: title, description, a tappable link and its licence.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.body,
    required this.linkLabel,
    required this.linkUrl,
    required this.licenseLabel,
    required this.licenseUrl,
  });

  final String title;
  final String body;
  final String linkLabel;
  final String linkUrl;
  final String licenseLabel;
  final String licenseUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyStrong),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _LinkChip(label: linkLabel, url: linkUrl),
          const SizedBox(height: 8),
          _LinkChip(label: licenseLabel, url: licenseUrl),
        ],
      ),
    );
  }
}

/// A tappable link. Without a browser-launch dependency in the project, tapping
/// copies the URL to the clipboard and confirms — the user can paste it anywhere.
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.url});

  final String label;
  final String url;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface2,
          content: Text(
            'Havola nusxalandi: $url',
            style: AppTextStyles.caption.copyWith(color: AppColors.text),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      borderRadius: AppRadii.chipR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gem,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gem,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
