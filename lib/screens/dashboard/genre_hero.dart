import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';

/// Repères de la transition partagée entre la tuile d'un genre et le
/// bandeau de sa page. La portée en fait partie : la tuile « Action » de
/// l'accueil Films n'est pas celle de l'accueil Séries.
Object genreImageTag(BaseItemKind? kind, String? libraryId, String label) =>
    ('genre-image', kind?.name, libraryId, label);
Object genreTitleTag(BaseItemKind? kind, String? libraryId, String label) =>
    ('genre-title', kind?.name, libraryId, label);

/// Fond d'un genre : l'image sous un voile, de la tuile ([mix] 0 : coins
/// arrondis, voile sombre uniforme) au bandeau ([mix] 1 : coins vifs, voile
/// qui rejoint le fond de la page, cf. CLAUDE.md § Texte sur image).
class GenreBackdrop extends StatelessWidget {
  const GenreBackdrop({required this.image, required this.mix, super.key});
  final ImageData? image;
  final double mix;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius:
            BorderRadius.lerp(AppRadii.cardBorder, BorderRadius.zero, mix)!,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: AppColors.surface),
          // En bandeau, l'image s'arrête 2 px avant le bord : le voile (déjà
          // opaque, de la couleur du fond) recouvre seul la dernière ligne.
          // Sinon, à une position fractionnaire, l'image et le voile
          // antialiasent leur bord ensemble et laissent filtrer un trait
          // clair d'un pixel.
          if (image case final image?)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 2 * mix,
              child: KinosImage(
                  image: image,
                  fit: BoxFit.cover,
                  imageErrorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Opacity(
            opacity: 1 - mix,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.scrim.withValues(alpha: .55),
                    AppColors.scrim.withValues(alpha: .8),
                  ],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: mix,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.scrim.withValues(alpha: .55),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
        ]),
      );
}

/// Avancement du vol, 0 à la plus petite des deux extrémités et 1 à la plus
/// grande, d'après la taille courante : indépendant du sens (ouverture ou
/// retour) et de la courbe.
double _flightMix(double current, double a, double b) {
  final low = math.min(a, b), high = math.max(a, b);
  return high - low < 1
      ? 1.0
      : ((current - low) / (high - low)).clamp(0.0, 1.0);
}

Size _sizeOf(BuildContext context) =>
    (context.findRenderObject() as RenderBox).size;

/// [GenreBackdrop] dans un [Hero] : la tuile ([mix] 0) devient le bandeau
/// ([mix] 1) et inversement au retour. Sans mouvement (clavier, animations
/// réduites), le fond seul, sans vol.
Widget genreBackdropHero(BuildContext context,
    {required Object tag, required ImageData? image, required double mix}) {
  final backdrop = GenreBackdrop(image: image, mix: mix);
  if (!AppMotion.enabled(context)) return backdrop;
  return Hero(
    tag: tag,
    // Ligne droite : l'arc par défaut serait étrange sur un bandeau.
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: (_, __, ___, fromContext, toContext) {
      final from = _sizeOf(fromContext).height, to = _sizeOf(toContext).height;
      return LayoutBuilder(
          builder: (_, constraints) => GenreBackdrop(
              image: image, mix: _flightMix(constraints.maxHeight, from, to)));
    },
    child: backdrop,
  );
}

/// Nom du genre dans un [Hero] : du centre de la tuile ([big] faux, style
/// de titre de section) à son emplacement sur la page ([big] vrai, grand
/// titre), le style s'interpolant pendant le vol. Sans mouvement, le texte
/// seul.
Widget genreTitleHero(BuildContext context,
    {required Object tag,
    required String label,
    required bool big,
    TextAlign textAlign = TextAlign.start,
    int maxLines = 1}) {
  final theme = Theme.of(context).textTheme;
  TextStyle? style(TextStyle? base) =>
      base?.copyWith(color: AppColors.textPrimary);
  final text = Material(
    type: MaterialType.transparency,
    child: Text(label,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style(big ? theme.displayMedium : theme.headlineMedium)),
  );
  if (!AppMotion.enabled(context)) return text;
  return Hero(
    tag: tag,
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: (flightContext, _, __, fromContext, toContext) {
      final from = _sizeOf(fromContext).width, to = _sizeOf(toContext).width;
      final flightTheme = Theme.of(flightContext).textTheme;
      return LayoutBuilder(builder: (_, constraints) {
        final mix = _flightMix(constraints.maxWidth, from, to);
        // Le petit style a toujours la plus petite largeur : mix 0 = tuile.
        final small = style(flightTheme.headlineMedium);
        final large = style(flightTheme.displayMedium);
        return Material(
          type: MaterialType.transparency,
          child: Text(label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle.lerp(small, large, mix)),
        );
      });
    },
    child: text,
  );
}
