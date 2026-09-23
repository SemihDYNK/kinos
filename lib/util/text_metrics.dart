import 'package:flutter/material.dart';

/// Hauteur réelle qu'occupe [style] sur une ligne, telle que Flutter la
/// pose vraiment — jamais `style.fontSize! * style.height!` : ce produit
/// est une approximation, la hauteur de ligne effective dépend aussi de
/// l'arrondi interne du moteur de texte (mesuré : 23.0 px pour
/// `AppTypography.body`, 22.5 attendu ; 18.0 px pour `AppTypography.meta`,
/// 18.2 attendu — cf. le débordement de 0.5 px sous les vignettes
/// d'épisode que cette approximation a causé). Passe le `textScaler`
/// ambiant pour rester exact si l'utilisateur a agrandi le texte système.
double measuredLineHeight(
  BuildContext context,
  TextStyle? style, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(text: 'Hg', style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  return painter.height;
}
