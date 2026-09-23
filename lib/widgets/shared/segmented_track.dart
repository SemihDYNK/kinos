import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Piste unique (fond, segment secondaire optionnel, segment principal)
/// partagée par la barre de progression du lecteur
/// (`video_progress_bar.dart`) et la barre de volume
/// (`video_volume_slider.dart`) — même grammaire visuelle pour les deux :
/// fond `AppColors.progressTrack`, segment principal
/// `AppColors.textPrimary` plein, segment secondaire (tampon vidéo —
/// sans équivalent côté volume) en opacité réduite, jamais de trou.
///
/// `Stack(fit: StackFit.expand)`, jamais le défaut `loose` : un `Stack`
/// ne force pas ses enfants non positionnés à occuper toute sa taille —
/// sans ce budget, chaque couche se réduit à une hauteur de 0 alors que
/// la piste elle-même mesure correctement sa largeur/hauteur (mesuré
/// via RenderBox — c'était la cause exacte d'une piste invisible
/// rapportée sur la barre de progression).
class SegmentedTrack extends StatelessWidget {
  /// Hauteur au repos / au survol-focus — communes aux deux barres
  /// (progression et volume), pour qu'elles restent visuellement
  /// identiques par construction plutôt que par convention répétée.
  static const heightRest = AppSpacing.xxs; // 4
  static const heightHover = AppSpacing.xxs * 1.5; // 6

  final double height;

  /// Fraction (0-1) du segment principal (lu / volume courant).
  final double primaryFraction;

  /// Fraction (0-1) du segment secondaire (tampon vidéo) — `null` : pas
  /// de second segment (cas de la barre de volume).
  final double? secondaryFraction;

  const SegmentedTrack({
    required this.height,
    required this.primaryFraction,
    this.secondaryFraction,
    super.key,
  });

  /// Clés stables (mesure directe en test — `find.byKey` plutôt que de
  /// distinguer plusieurs `ColoredBox` par position dans l'arbre).
  static const backgroundKey = ValueKey('segmented-track-background');
  static const secondaryKey = ValueKey('segmented-track-secondary');
  static const primaryKey = ValueKey('segmented-track-primary');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.controlBorder,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.centerLeft,
        children: [
          const ColoredBox(
              key: backgroundKey, color: AppColors.progressTrack),
          if (secondaryFraction != null)
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: secondaryFraction!.clamp(0.0, 1.0),
              child: ColoredBox(
                key: secondaryKey,
                color: AppColors.textPrimary.withValues(alpha: 0.3),
              ),
            ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: primaryFraction.clamp(0.0, 1.0),
            child: const ColoredBox(key: primaryKey, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
