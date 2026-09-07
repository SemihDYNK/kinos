import 'package:flutter/material.dart';

import 'package:fladder/theme/app_theme.dart';

/// Fine barre de progression, alignée sur le bord bas d'une vignette —
/// visible seulement si [progress] (0-100) est entamé. Partagée entre
/// "Continuer à regarder" et la liste d'épisodes d'une saison.
class MediaProgressBar extends StatelessWidget {
  final double progress;

  const MediaProgressBar({required this.progress, super.key});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          value: (progress / 100).clamp(0, 1),
          minHeight: 3,
          backgroundColor: AppColors.progressTrack,
          valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
        ),
      ),
    );
  }
}
