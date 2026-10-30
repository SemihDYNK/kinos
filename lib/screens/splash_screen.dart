import 'dart:async';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/startup_curtain.dart';
import 'package:kinos/screens/shared/startup_home.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/screens/shared/route_wrapper.dart';
import 'package:kinos/services/local_network_permission.dart';

@RoutePage()
class SplashScreen extends ConsumerStatefulWidget {
  final Function(bool loggedIn)? loggedIn;
  const SplashScreen({this.loggedIn, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((value) async {
      final AccountModel? lastUsedAccount =
          await ref.read(sharedUtilityProvider).getActiveAccount();
      if (!mounted) return;
      ref.read(userProvider.notifier).updateUser(lastUsedAccount);

      if (context.mounted) {
        if (lastUsedAccount == null ||
            ref.read(argumentsStateProvider).newWindow == true) {
          callBackOrNavigate(false);
        } else {
          !await ensureLocalNetworkPermissions(
            [
              lastUsedAccount.credentials.url,
              lastUsedAccount.credentials.localUrl
            ],
            context,
          );

          switch (lastUsedAccount.authMethod) {
            case Authentication.autoLogin:
              callBackOrNavigate(true);
              break;
            case Authentication.biometrics:
            case Authentication.none:
            case Authentication.passcode:
              callBackOrNavigate(false);
              break;
          }
        }
      }
    });
  }

  Future<void> callBackOrNavigate(bool loggedIn) async {
    if (loggedIn) {
      try {
        await _prepareHome().timeout(AppDurations.startupLoadTimeout);
      } catch (_) {
        // An unavailable server must not trap the user behind the splash.
      }
    }
    if (!mounted) return;
    ref.read(startupPageReadyProvider.notifier).state = false;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry curtain;
    curtain = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Consumer(
            builder: (context, overlayRef, _) => StartupCurtain(
                  ready:
                      !loggedIn || overlayRef.watch(startupPageReadyProvider),
                  onRevealed: () {
                    curtain.remove();
                    curtain.dispose();
                  },
                )),
      ),
    );
    overlay.insert(curtain);
    if (widget.loggedIn == null) {
      if (loggedIn) {
        context.router.replace(const DashboardRoute());
      } else {
        context.router.replace(LoginRoute());
      }
    } else {
      widget.loggedIn?.call(loggedIn);
      context.router.maybePop(loggedIn);
    }
  }

  Future<void> _prepareHome() async {
    await ref.read(startupHomeProvider.future);
    if (!mounted) return;
    final hero = ref.read(heroItemsProvider).asData?.value.firstOrNull;
    if (hero == null) return;
    final image = hero.getPosters?.backDrop?.firstOrNull ??
        hero.getPosters?.primary ??
        hero.getPosters?.thumb;
    final logo = hero.tvPosterLogo;
    await Future.wait([
      for (final artwork in [
        image,
        logo,
        ...[
          ...ref.read(dashboardProvider).resumeVideo,
          ...ref.read(dashboardProvider).nextUp,
          ...ref
              .read(viewsProvider)
              .dashboardViews
              .expand((view) => view.recentlyAdded),
        ].take(8).map((item) => item.tvPosterSmall),
      ])
        if (artwork != null &&
            artwork.path.isNotEmpty &&
            artwork.key.endsWith('_logo_null') != true)
          precacheImage(artwork.imageProvider, context, onError: (_, __) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return const RouteWrapper(
      child: Scaffold(
        body: SizedBox.expand(child: StartupCurtain()),
      ),
    );
  }
}
