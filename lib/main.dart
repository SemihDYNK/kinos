import 'package:kinos/util/motion_input.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/bootstrap/app_bootstrap.dart';
import 'package:kinos/bootstrap/platform/platform_app_wrapper.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/crash_log_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/sync_provider.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:kinos/routes/auto_router.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/application_info.dart';
import 'package:kinos/util/deep_link_helper.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/themes_data.dart';
import 'package:kinos/widgets/media_query_scaler.dart';
import 'package:kinos/widgets/pip_lifecycle_controller.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await bootstrapApplication(args);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => bootstrap.sharedPreferences),
        applicationInfoProvider.overrideWith((ref) => bootstrap.applicationInfo),
        crashLogProvider.overrideWith((ref) => bootstrap.crashProvider),
        argumentsStateProvider.overrideWith((ref) => bootstrap.argumentsModel),
        syncProvider.overrideWith((ref) => SyncNotifier(ref, bootstrap.applicationDirectory)),
      ],
      child: AdaptiveLayoutBuilder(
        child: (context) => const Main(),
      ),
    ),
  );
}

class Main extends ConsumerWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformAppWrapper(
      builder: (context, autoRouter) {
        return _KinosApp(
          autoRouter: autoRouter,
        );
      },
    );
  }
}

class _KinosApp extends ConsumerWidget {
  const _KinosApp({
    required this.autoRouter,
  });

  final AutoRouter autoRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mouseDrag = ref.watch(clientSettingsProvider.select((value) => value.mouseDragSupport));
    final language = ref.watch(clientSettingsProvider
        .select((value) => value.selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale));
    final scrollBehaviour = const MaterialScrollBehavior();
    final theme = ref.watch(appThemeProvider);

    // Thème sombre unique (lib/theme/app_theme.dart) : pas de variante claire,
    // pas de couleur d'accent dynamique. `light`/`dark` restent identiques
    // uniquement pour ne pas casser les écrans qui lisent encore ThemesData.
    return ThemesData(
      light: theme,
      dark: theme,
      child: MaterialApp.router(
        theme: theme,
        themeMode: ThemeMode.dark,
        scrollBehavior: scrollBehaviour.copyWith(
          dragDevices: {
            ...scrollBehaviour.dragDevices,
            mouseDrag ? PointerDeviceKind.mouse : null,
          }.nonNulls.toSet(),
        ),
        localizationsDelegates: KinosLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: language,
        localeResolutionCallback: (locale, supportedLocales) {
          const fallback = Locale('en');
          if (locale == null) return fallback;
          if (supportedLocales.contains(locale)) {
            return locale;
          }
          final matchByLanguage = supportedLocales.firstWhere(
            (l) => l.languageCode == locale.languageCode,
            orElse: () => fallback,
          );

          return matchByLanguage;
        },
        builder: (context, child) => AnimatedTheme(
          duration: AppDurations.heroTint,
          data: ref.watch(appThemeProvider),
          child: MediaQueryScaler(
            child: LocalizationContextWrapper(
              child: MotionInputBoundary(
                  child: PipLifecycleController(child: child ?? Container())),
              currentLocale: language,
            ),
            enable: ref.read(argumentsStateProvider).leanBackMode,
          ),
        ),
        debugShowCheckedModeBanner: false,
        routerConfig: autoRouter.config(
          deepLinkBuilder: (deepLink) => deepLinkBuilder(deepLink.uri),
        ),
      ),
    );
  }
}
