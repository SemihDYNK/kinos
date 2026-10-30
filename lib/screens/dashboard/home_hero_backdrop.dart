import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kinos/models/items/images_models.dart';
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
  // Le ShaderMask peut laisser une rangée sombre au bord fractionnaire de
  // son calque sur le rendu Linux. Un clip rectangulaire sans anticrénelage
  // empêche cette rangée de déborder sur le fond de la section suivante.
  Widget build(BuildContext context) {
    final imageWidget = KinosImage(
        key: ValueKey(_shown?.key),
        image: _shown,
        alignment: AppHeroLayout.imageAlignment,
        disableBlur: true);
    return ClipRect(
        child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [
          0,
          cinematic
              ? AppDetailLayout.movieImageFadeStart
              : AppHeroLayout.imageFadeStart,
          1
        ],
        colors: const [Colors.white, Colors.white, Colors.transparent],
      ).createShader(rect),
      child: Stack(fit: StackFit.expand, children: [
        if (AppMotion.enabled(context))
          AnimatedSwitcher(
            duration:
                cinematic ? AppDurations.heroTint : AppDurations.heroSlide,
            reverseDuration: AppDurations.pageTransition,
            switchInCurve: AppMotion.easeOut,
            switchOutCurve: AppMotion.easeOut,
            // Sans clé sur la transition : A → B → A peut garder deux sorties A.
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: imageWidget,
          )
        else
          imageWidget,
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
            AppColors.scrim
                .withValues(alpha: AppHeroLayout.imageUpperScrimOpacity),
            AppColors.scrim
                .withValues(alpha: AppHeroLayout.imageReadingScrimOpacity),
            AppColors.scrim.withValues(alpha: AppHeroLayout.imageScrimOpacity),
          ],
        ))),
      ]),
    ));
  }
}
