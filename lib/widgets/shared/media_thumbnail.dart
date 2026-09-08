import 'package:flutter/material.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/fladder_image.dart';

/// Vignette 16:9 avec repli : [thumbnail] (Thumb ou Backdrop, déjà en
/// 16:9) en cover si disponible, sinon [fallback] (typiquement Primary,
/// portrait) centrée sans rognage sur fond neutre — jamais forcée en
/// cover, ce qui la couperait n'importe où. Partagée entre "Continuer à
/// regarder" et la liste d'épisodes d'une saison.
class MediaThumbnail extends StatelessWidget {
  final ImageData? thumbnail;
  final ImageData? fallback;

  const MediaThumbnail(
      {required this.thumbnail, required this.fallback, super.key});

  @override
  Widget build(BuildContext context) {
    if (thumbnail != null) {
      return FladderImage(image: thumbnail, fit: BoxFit.cover);
    }
    if (fallback == null) {
      return const ColoredBox(color: AppColors.surface);
    }
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: FladderImage(image: fallback, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
