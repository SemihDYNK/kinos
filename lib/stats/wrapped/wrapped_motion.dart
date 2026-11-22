import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';

/// L'horloge d'une diapo : ses secondes écoulées, et sa durée. Tout le
/// mouvement d'une diapo s'écrit en secondes depuis son début, comme un
/// générique minuté.
class WrappedClock extends InheritedNotifier<Animation<double>> {
  const WrappedClock(
      {required this.duration,
      required this.motion,
      required Animation<double> progress,
      required super.child,
      super.key})
      : super(notifier: progress);

  /// Durée de la diapo, en secondes.
  final double duration;

  /// Faux quand le système demande moins de mouvement : tout est posé.
  final bool motion;

  static WrappedClock _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WrappedClock>()!;

  /// Secondes écoulées depuis le début de la diapo.
  static double seconds(BuildContext context) {
    final clock = _of(context);
    return (clock.notifier?.value ?? 1) * clock.duration;
  }

  static bool motionOf(BuildContext context) => _of(context).motion;

  /// Avancement de 0 à 1 d'un mouvement qui commence à [at] et dure
  /// [length] secondes. 1 sans mouvement.
  static double at(BuildContext context, double at,
      {double length = AppWrapped.reveal, Curve curve = AppMotion.easeOut}) {
    final clock = _of(context);
    if (!clock.motion) return 1;
    final t = ((clock.notifier?.value ?? 1) * clock.duration - at) / length;
    return curve.transform(t.clamp(0.0, 1.0));
  }
}

/// Les tailles de texte d'une diapo, proportionnelles à sa hauteur.
class WrappedType {
  WrappedType(Size size)
      : big = AppTypography.heroEditorial.copyWith(
            fontSize: size.height * AppWrapped.bigFraction,
            height: 1,
            color: AppColors.textPrimary),
        mid = AppTypography.display.copyWith(
            fontSize: size.height * AppWrapped.midFraction,
            height: 1.15,
            color: AppColors.textPrimary),
        small = AppTypography.body.copyWith(
            fontSize: math.max(
                AppWrapped.minSmall, size.height * AppWrapped.smallFraction),
            height: 1.5,
            color: AppColors.textPrimary.withValues(alpha: .75)),
        cap = AppTypography.overline.copyWith(
            fontSize: math.max(
                AppWrapped.minCap, size.height * AppWrapped.capFraction),
            color: AppColors.textPrimary.withValues(alpha: .75));

  final TextStyle big;
  final TextStyle mid;
  final TextStyle small;
  final TextStyle cap;
}

/// Un texte qui entre comme au générique : fondu, légère montée, et ses
/// lettres qui se resserrent. Les petites capitales gardent leur grand
/// espacement.
class WrappedText extends StatelessWidget {
  const WrappedText(this.text,
      {required this.style,
      required this.at,
      this.caps = false,
      this.textAlign,
      this.maxLines,
      super.key});
  final String text;
  final TextStyle style;
  final double at;
  final bool caps;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final p = WrappedClock.at(context, at);
    final tracking = WrappedClock.at(context, at,
        length: AppWrapped.tracking, curve: Curves.easeOutCubic);
    final size = style.fontSize ?? 14;
    final spacing = caps
        ? size * AppWrapped.capTracking
        : (style.letterSpacing ?? 0) +
            size * AppWrapped.trackingFrom * (1 - tracking);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, (1 - p) * size * .2),
        child: Text(caps ? text.toUpperCase() : text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: style.copyWith(letterSpacing: spacing)),
      ),
    );
  }
}

/// L'image avance lentement sur toute la diapo, comme une caméra.
class KenBurns extends StatelessWidget {
  const KenBurns(
      {required this.child,
      this.from = 0,
      this.length,
      this.amount = AppWrapped.kenBurns,
      super.key});
  final Widget child;

  /// Début et durée du mouvement (secondes) ; toute la diapo par défaut.
  final double from;
  final double? length;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final clock = context.dependOnInheritedWidgetOfExactType<WrappedClock>()!;
    final p = WrappedClock.at(context, from,
        length: length ?? clock.duration, curve: Curves.linear);
    return ClipRect(
        child: Transform.scale(scale: 1 + amount * p, child: child));
  }
}

/// Une image de film en plein cadre.
class WrappedImage extends StatelessWidget {
  const WrappedImage(this.image, {this.alignment, super.key});
  final ImageData? image;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) => image == null
      ? const ColoredBox(color: AppColors.heroFallback)
      : KinosImage(
          key: ValueKey(image!.key),
          image: image,
          alignment: alignment ?? AppHeroLayout.imageAlignment,
          disableBlur: true);
}

/// Les images de plusieurs films qui se relaient en fondu, chacune avec son
/// avancée lente.
class CyclingBackdrops extends StatelessWidget {
  const CyclingBackdrops(this.images, {super.key});
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const ColoredBox(color: AppColors.heroFallback);
    }
    final t = WrappedClock.seconds(context);
    final index = WrappedClock.motionOf(context)
        ? (t / AppWrapped.backdropCycle).floor() % images.length
        : 0;
    final start =
        (t / AppWrapped.backdropCycle).floor() * AppWrapped.backdropCycle;
    return AnimatedSwitcher(
      duration: WrappedClock.motionOf(context)
          ? const Duration(milliseconds: 1600)
          : Duration.zero,
      child: KenBurns(
          key: ValueKey(index),
          from: start,
          length: AppWrapped.backdropCycle * 1.5,
          child: WrappedImage(images[index])),
    );
  }
}

/// Le voile de lecture : uniforme, puis dégradé depuis le côté du texte
/// (gauche) et le bas. [opacity] permet de le faire entrer.
class WrappedScrim extends StatelessWidget {
  const WrappedScrim(
      {this.opacity = 1, this.veil = AppWrapped.veil, super.key});
  final double opacity;
  final double veil;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: AppColors.scrim.withValues(alpha: veil * .6)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0, .45, AppWrapped.scrimReach],
                  colors: [
                    AppColors.scrim.withValues(alpha: AppWrapped.scrim),
                    AppColors.scrim.withValues(alpha: AppWrapped.scrim * .7),
                    AppColors.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0, .45],
                  colors: [
                    AppColors.scrim.withValues(alpha: veil),
                    AppColors.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Le bloc de texte d'une diapo, à gauche et centré verticalement.
class WrappedTextBlock extends StatelessWidget {
  const WrappedTextBlock(
      {required this.children,
      this.alignment = Alignment.centerLeft,
      this.crossAxisAlignment = CrossAxisAlignment.start,
      this.widthFraction = .62,
      super.key});
  final List<Widget> children;
  final Alignment alignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double widthFraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => Padding(
            padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * AppWrapped.inset),
            child: Align(
              alignment: alignment,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * widthFraction),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: children),
              ),
            ),
          ));
}
