import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/l10n/app_locales.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: AppLocales.path,
      startLocale: AppLocales.start,
      fallbackLocale: AppLocales.fallback,
      child: const SozJangiApp(),
    ),
  );
}
