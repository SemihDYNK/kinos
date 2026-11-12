import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';

/// Routeur qui n'ouvre rien : enregistre la dernière route poussée.
class RecordingRouter extends RootStackRouter {
  PageRouteInfo? opened;
  bool popped = false;
  @override
  List<AutoRoute> get routes => [];
  @override
  Future<T?> push<T extends Object?>(PageRouteInfo route,
      {OnNavigationFailure? onFailure}) async {
    opened = route;
    return null;
  }

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    popped = true;
    return true;
  }
}

/// Une page entière (qui porte son propre Scaffold) dans une fenêtre de
/// bureau, avec le routeur [router].
Widget pageShell(Widget page, RecordingRouter router, {double textScale = 1}) =>
    StackRouterScope(
      controller: router,
      stateHash: 0,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(density: AppDensity.desk),
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(1400, 900),
              textScaler: TextScaler.linear(textScale)),
          child: AdaptiveLayout(
              data: const AdaptiveLayoutModel(
                  viewSize: ViewSize.desktop,
                  layoutMode: LayoutMode.single,
                  inputDevice: InputDevice.pointer,
                  platform: TargetPlatform.linux,
                  isDesktop: true,
                  posterDefaults: PosterDefaults(size: 180, ratio: 2 / 3),
                  controller: {},
                  sideBarWidth: 0,
                  topBarHeight: 0,
                  statusBarHeight: 0),
              child: page),
        ),
      ),
    );
