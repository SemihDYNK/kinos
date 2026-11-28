import 'dart:async';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/startup_aurora.dart';
import 'package:kinos/screens/shared/startup_curtain.dart';
import 'package:kinos/screens/shared/startup_frame_log.dart';
import 'package:kinos/screens/shared/startup_home.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/screens/shared/route_wrapper.dart';
import 'package:kinos/services/local_network_permission.dart';
import 'package:kinos/services/startup_session.dart';
import 'package:kinos/services/startup_sounds.dart';

@RoutePage()
class SplashScreen extends ConsumerStatefulWidget {
  final Function(bool loggedIn)? loggedIn;
  const SplashScreen({this.loggedIn, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _logoReady = Completer<void>();

  /// L'animation choisie pour ce lancement (réglage, ou premier lancement
  /// depuis le démarrage de la machine) ; le lancement est noté.
  late final StartupIntro _choice =
      resolveStartupIntro(ref.read(sharedPreferencesProvider));

  /// Intro du projecteur (gros plan, clap, aurore, faisceau), sauf pour une
  /// fenêtre secondaire ou avec l'ancienne animation. (Au lancement, la
  /// garde d'authentification ouvre cet écran avec [SplashScreen.loggedIn] :
  /// c'est le chemin normal.)
  late final bool _intro = ref.read(argumentsStateProvider).newWindow != true &&
      _choice != StartupIntro.legacy;

  /// Le mot « KINOS » après le clap : la version complète.
  late final bool _word = _intro && _choice == StartupIntro.long;

  /// Sons de l'intro, prêts (ou `null` : réglage coupé, animations
  /// réduites, lecture audio indisponible). Ils survivent à cet écran : le
  /// projecteur joue pendant l'ouverture, sur l'accueil.
  StartupSounds? _sounds;

  void _prepareSounds() {
    if (!_intro ||
        !startupSoundEnabled(ref.read(sharedPreferencesProvider)) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    unawaited(StartupSounds.prepare().then((sounds) {
      // Prêts après coup : le clap déjà passé ne joue pas en retard.
      _sounds = sounds;
    }));
  }

  @override
  void initState() {
    super.initState();
    // Le fond liquide du clap : prêt bien avant lui (repli sur l'aurore).
    if (_intro) unawaited(StartupAurora.loadLiquid());
    // Relevé des images lentes, jusqu'à la fin de la révélation.
    if (ref.read(argumentsStateProvider).newWindow != true) {
      StartupFrameLog.start();
    }
    WidgetsBinding.instance.addPostFrameCallback((value) async {
      _prepareSounds();
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
    // Home preparation and the signature assembly run concurrently.
    await _logoReady.future
        .timeout(AppDurations.startupLoadTimeout, onTimeout: () {});
    if (!mounted) return;
    ref.read(startupPageReadyProvider.notifier).state = false;
    ref.read(startupCurtainPhaseProvider.notifier).state =
        StartupCurtainPhase.covering;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry curtain;
    curtain = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Consumer(
            builder: (context, overlayRef, _) => StartupCurtain(
                  intro: _intro,
                  word: _word,
                  tint: overlayRef.watch(startupTintProvider),
                  ready:
                      !loggedIn || overlayRef.watch(startupPageReadyProvider),
                  onWindow: () {
                    _sounds?.window();
                    // La nappe s'éteint d'ici la fin de l'ouverture.
                    _sounds?.fadeAurora(AppDurations.startupIntroReveal *
                        (1 - AppMotion.startupIntroBeamOpen.begin));
                  },
                  onOpening: () {
                    // Le faisceau surgit du K.
                    _sounds?.beam();
                    overlayRef
                        .read(startupCurtainPhaseProvider.notifier)
                        .state = StartupCurtainPhase.opening;
                  },
                  onRevealed: () {
                    // Les derniers sons finissent leur fondu avant d'être
                    // libérés.
                    _sounds?.release();
                    StartupFrameLog.stop();
                    overlayRef
                        .read(startupCurtainPhaseProvider.notifier)
                        .state = StartupCurtainPhase.none;
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
    Future<void> precache(Iterable<ImageData?> artwork) => Future.wait<void>([
          for (final image in artwork)
            if (image != null &&
                image.path.isNotEmpty &&
                image.key.endsWith('_logo_null') != true)
              precacheImage(image.imageProvider, context, onError: (_, __) {}),
        ]).then<void>((_) {});

    // Le rideau s'ouvre sur le bandeau : son image est la seule attendue
    // jusqu'au bout. Elle part dès que les films du carrousel sont connus,
    // sans attendre le reste de l'accueil : tirée au hasard à chaque
    // lancement, elle n'est presque jamais en cache et le serveur doit
    // souvent la redimensionner.
    Future<void> heroArtwork() async {
      final hero = (await ref.read(heroItemsProvider.future)).firstOrNull;
      if (hero == null || !mounted) return;
      final backdrop = hero.getPosters?.backDrop?.firstOrNull ??
          hero.getPosters?.primary ??
          hero.getPosters?.thumb;
      // La dominante du film, pour le dégradé du clap (sans retenir le
      // rideau : elle arrive quand elle arrive). Le service la garde en
      // cache, le bandeau la retrouvera aussitôt.
      if (_intro && backdrop != null && backdrop.path.isNotEmpty) {
        unawaited(ref
            .read(paletteServiceProvider)
            .forItem(itemId: hero.id, image: backdrop.imageProvider)
            .then((palette) {
          if (mounted && !palette.isFallback) {
            ref.read(startupTintProvider.notifier).state = palette.tint;
          }
        }, onError: (_) {}));
      }
      await precache([backdrop, hero.tvPosterLogo]);
    }

    // Les vignettes en dessous ont un court délai, puis arrivent en fondu
    // (leur chargement continue) : sans cache, elles retenaient le rideau
    // plusieurs secondes.
    Future<void> posters() async {
      await ref.read(startupHomeProvider.future);
      if (!mounted) return;
      await precache([
        ...ref.read(dashboardProvider).resumeVideo,
        ...ref.read(dashboardProvider).nextUp,
        ...ref
            .read(viewsProvider)
            .dashboardViews
            .expand((view) => view.recentlyAdded),
      ].take(8).map((item) => item.tvPosterSmall))
          .timeout(AppDurations.startupArtworkBudget, onTimeout: () {});
    }

    await Future.wait<void>([heroArtwork(), posters()]);
  }

  @override
  Widget build(BuildContext context) {
    return RouteWrapper(
      child: Scaffold(
        body: SizedBox.expand(
            child: StartupCurtain(
                intro: _intro,
                word: _word,
                tint: ref.watch(startupTintProvider),
                onClap: () => _sounds?.clap(),
                onLogoReady: () {
                  if (!_logoReady.isCompleted) _logoReady.complete();
                })),
      ),
    );
  }
}
