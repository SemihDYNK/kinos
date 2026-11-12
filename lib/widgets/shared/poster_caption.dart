import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Hauteur d'une ligne du style [style] à l'échelle de texte courante.
double _lineHeight(BuildContext context, TextStyle? style) => TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    ).preferredLineHeight;

/// Hauteur de la légende sous une jaquette : l'écart, le titre et l'année.
/// À budgéter dans toute cellule à hauteur fixe qui porte une
/// [PosterCaption].
double posterCaptionHeight(BuildContext context) {
  final theme = Theme.of(context).textTheme;
  return AppSpacing.xs +
      _lineHeight(context, theme.titleMedium) +
      _lineHeight(context, theme.bodySmall);
}

/// Hauteur d'une cellule de grille « jaquette 2:3 + légende », anneau de
/// focus compris, pour une cellule de largeur [tileWidth].
double captionedPosterHeight(BuildContext context, double tileWidth) {
  final inset = FocusRing.boxInset(context);
  return (tileWidth - inset) / AppMedia.posterAspectRatio +
      inset +
      posterCaptionHeight(context);
}

/// Titre sur une ligne puis année (ou autre mention) sous une jaquette :
/// beaucoup d'affiches n'ont pas leur titre imprimé.
class PosterCaption extends StatelessWidget {
  const PosterCaption({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.titleMedium),
        Text(subtitle ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall),
      ],
    );
  }
}
