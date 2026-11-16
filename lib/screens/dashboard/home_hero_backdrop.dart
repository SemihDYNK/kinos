import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/screens/dashboard/hero_scroll_depth.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';

/// Image limitée au bandeau ; le dégradé de couleur appartient à la section.
class HomeHeroBackdrop extends StatefulWidget {
  const HomeHeroBackdrop(
      {required this.image, this.fallback, this.cinematic = false, super.key});
  final ImageData? image;
  final ImageData? fallback;
  final bool cinematic;

  @override
  State<HomeHeroBackdrop> createState() => _HomeHeroBackdropState();
}

class _HomeHeroBackdropState extends State<HomeHeroBackdrop> {
  late ImageData? _shown = widget.fallback ?? widget.image;
  ImageProvider? _requested;
  bool get cinematic => widget.cinematic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(HomeHeroBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    // Le carrousel conserve son préchargement et son fondu existants.
    if (!cinematic && widget.fallback == null) {
      _shown = widget.image;
      return;
    }
    final image = widget.image;
    final provider = image?.imageProvider;
    if (provider == _requested) return;
    _requested = provider;
    if (image == null || provider == null) {
      _shown = widget.fallback;
      return;
    }
    if (provider == _shown?.imageProvider) return;
    var failed = false;
    unawaited(
        precacheImage(provider, context, onError: (_, __) => failed = true)
            .then((_) {
      if (!mounted || failed || provider != _requested) return;
      setState(() => _shown = image);
    }));
  }

  @override
  // Le ShaderMask (dstIn) ne couvre qu'une fraction de la dernière rangée
  // de pixels quand le bord de son calque est fractionnaire (40 % par
  // exemple) : il y laisse passer 60 % de l'image assombrie, d'où une ligne
  // sombre au bas du bandeau, plus ou moins visible selon le défilement.
  // Le calque masqué dépasse donc de [AppHeroLayout.seamGuard] sous le
  // contenu visible : son bord fractionnaire tombe hors du clip, et le
  // dégradé reste identique sur la zone affichée.
  Widget build(BuildContext context) {
    final imageWidget = KinosImage(
        key: ValueKey(_shown?.key),
        image: _shown,
        alignment: AppHeroLayout.imageAlignment,
        disableBlur: true);
    const guard = AppHeroLayout.seamGuard;
    return ClipRect(
      child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -guard,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              // Fractions relatives à la zone affichée, pas à la garde.
              final visible = (rect.height - guard) / rect.height;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [
                  0,
                  (cinematic
                          ? AppDetailLayout.movieImageFadeStart
                          : AppHeroLayout.imageFadeStart) *
                      visible,
                  visible,
                ],
                colors: const [Colors.white, Colors.white, Colors.transparent],
              ).createShader(rect);
            },
            child: Stack(fit: StackFit.expand, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: guard,
                child: Stack(fit: StackFit.expand, children: [
                  // Profondeur au défilement (cf. [HeroScrollDepth]) : seule
                  // l'image se décale, sous le masque et les voiles fixés au
                  // bandeau, dont le fondu du bas reste intact.
                  ValueListenableBuilder<double>(
                    valueListenable: HeroScrollDepth.parallaxOf(context),
                    builder: (context, shift, child) => Transform.translate(
                        offset: Offset(0, shift), child: child),
                    child: AppMotion.enabled(context)
                        ? AnimatedSwitcher(
                      duration: cinematic
                          ? AppDurations.heroTint
                          : AppDurations.heroSlide,
                      reverseDuration: AppDurations.pageTransition,
                      switchInCurve: AppMotion.easeOut,
                      switchOutCurve: AppMotion.easeOut,
                      // Sans clé sur la transition : A → B → A peut garder deux sorties A.
                      // Carrousel : la nouvelle image se pose en reculant
                      // légèrement pendant son fondu, comme une mise au
                      // point ; la fiche (cinematic) garde un fondu simple.
                      transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: cinematic
                              ? child
                              : ScaleTransition(
                                  scale: Tween(
                                          begin: 1 + AppMotion.heroImageSettle,
                                          end: 1.0)
                                      .animate(animation),
                                  alignment: AppHeroLayout.imageAlignment,
                                  child: child)),
                      child: imageWidget,
                    )
                        : imageWidget,
                  ),
                  ColoredBox(
                      color: AppColors.scrim.withValues(
                          alpha: cinematic
                              ? AppDetailLayout.movieImageScrim
                              : AppHeroLayout.imageUniformScrimOpacity)),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [
                      0,
                      AppHeroLayout.imageUpperScrimStart,
                      cinematic
                          ? AppDetailLayout.movieReadingScrimStart
                          : AppHeroLayout.imageReadingScrimStart,
                      1
                    ],
                    colors: [
                      AppColors.scrim.withValues(alpha: 0),
                      AppColors.scrim.withValues(
                          alpha: AppHeroLayout.imageUpperScrimOpacity),
                      AppColors.scrim.withValues(
                          alpha: AppHeroLayout.imageReadingScrimOpacity),
                      AppColors.scrim
                          .withValues(alpha: AppHeroLayout.imageScrimOpacity),
                    ],
                  ))),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
