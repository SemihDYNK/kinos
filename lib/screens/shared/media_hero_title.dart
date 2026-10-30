import 'package:flutter/material.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';

/// Identité du film : logo non déformé, titre complet accessible en repli.
class MediaHeroTitle extends StatelessWidget {
  const MediaHeroTitle(
      {required this.title,
      required this.logo,
      required this.availableWidth,
      super.key});
  final String title;
  final ImageData? logo;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final density = context.tokens.density;
    final fallback = Text(title.toUpperCase(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.heroEditorial.copyWith(
            fontSize: AppHeroLayout.titleSizeFor(availableWidth, density)));
    return Semantics(
        label: title,
        child: ExcludeSemantics(
            child: LayoutBuilder(builder: (context, constraints) {
          final image = logo;
          if (image == null || image.path.isEmpty) return fallback;
          return Image(
              key: ValueKey('media-logo-$title-${image.key}'),
              image: image.imageProvider,
              width: constraints.maxWidth
                  .clamp(0, AppHeroLayout.logoWidth * density.scale),
              height: AppHeroLayout.logoHeight * density.scale,
              fit: BoxFit.contain,
              alignment: AlignmentDirectional.centerStart,
              frameBuilder: (context, child, frame, synchronous) =>
                  Opacity(opacity: frame == null ? 0 : 1, child: child),
              errorBuilder: (context, error, stack) => fallback);
        })));
  }
}
