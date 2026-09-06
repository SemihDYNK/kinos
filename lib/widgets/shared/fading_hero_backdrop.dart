import 'package:flutter/material.dart';

import 'package:fladder/models/items/images_models.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/fladder_image.dart';

/// Image de fond pleine largeur qui continue derrière le contenu qui la
/// suit et se dissout sous un voile dégradé, plutôt que de s'arrêter net à
/// une hauteur fixe — partagée par [MediaDetailScaffold] (bandeau
/// film/série) et le tableau de bord (bandeau carrousel), pour un seul
/// composant de fond entre les deux écrans.
///
/// Une seule surface peinte, jamais deux : ce calque se dissout dans une
/// transparence TOTALE (`ShaderMask`), pas dans un aplat de substitution
/// posé par-dessus le fond de la page. Deux calques opaques distincts —
/// même strictement de la même couleur — restent deux surfaces séparées,
/// et leur jonction peut rester visible (bord de calque, artefact de
/// rendu). Une dissolution complète ne laisse qu'une seule surface : celle
/// du fond de la page, déjà correcte derrière tout, sans rien à raccorder.
class FadingHeroBackdrop extends StatelessWidget {
  /// Image affichée, cover, centrée.
  final ImageData? image;

  /// Teinte dominante de [image] (cf. `PaletteService`) — vers laquelle
  /// l'image glisse avant de se dissoudre.
  final Color heroTint;

  /// Hauteur, depuis le haut de ce calque, à partir de laquelle il doit
  /// être entièrement dissous (opacité 0). Doit correspondre à la seule
  /// hauteur de contenu garantie présente juste après ce calque (le bloc
  /// titre du bandeau, toujours là) — jamais à la hauteur totale de ce
  /// calque lui-même, qui peut largement dépasser un contenu réel plus
  /// court : ancrer la dissolution sur elle laisserait, sur un contenu
  /// court, le voile se faire couper avant d'avoir fini de se dissoudre.
  final double fadeCompleteBy;

  const FadingHeroBackdrop({
    required this.image,
    required this.heroTint,
    required this.fadeCompleteBy,
    super.key,
  });

  /// Distance (montée de teinte, puis dissolution) sur laquelle ce calque
  /// s'efface, comptée à rebours depuis [fadeCompleteBy].
  static const _rampDistance = 200.0;
  static const _resolveDistance = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // La hauteur réelle de ce calque vient de ses propres contraintes
        // (posé via SliverPositioned côté appelant) — pas d'un paramètre
        // séparé qui risquerait de diverger de la taille effective.
        final height = constraints.maxHeight;
        final rampStart = (fadeCompleteBy - _rampDistance - _resolveDistance)
            .clamp(0.0, fadeCompleteBy);
        final tintOpaqueAt =
            (fadeCompleteBy - _resolveDistance).clamp(0.0, fadeCompleteBy);
        final rampStartFraction = (rampStart / height).clamp(0.0, 1.0);
        final tintOpaqueFraction = (tintOpaqueAt / height).clamp(0.0, 1.0);
        final fadeEndFraction = (fadeCompleteBy / height).clamp(0.0, 1.0);

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, tintOpaqueFraction, fadeEndFraction],
            colors: const [Colors.white, Colors.white, Colors.transparent],
          ).createShader(rect),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // a. Fond teinté — visible au chargement et sur les bords.
              ColoredBox(color: heroTint),
              // b. Backdrop plein cadre, cover, centré — fondu croisé entre
              // deux images (ex. diapos du carrousel d'accueil), clé sur
              // ImageData.key pour ne redéclencher le fondu que sur un
              // changement réel d'image.
              AnimatedSwitcher(
                duration: AppDurations.heroTint,
                child: FladderImage(
                  key: ValueKey(image?.key),
                  image: image,
                  fit: BoxFit.cover,
                ),
              ),
              // c. Teinte qui monte progressivement : image nue jusqu'à
              // `rampStartFraction`, pleinement teintée (mais encore
              // opaque) à `tintOpaqueFraction`. La dissolution vers la
              // transparence totale est le rôle du ShaderMask ci-dessus,
              // pas de ce calque.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, rampStartFraction, tintOpaqueFraction],
                    colors: [
                      heroTint.withValues(alpha: 0),
                      heroTint.withValues(alpha: 0),
                      heroTint,
                    ],
                  ),
                ),
              ),
              // d. Dégradé horizontal — contraste pour le texte à gauche.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.55],
                    colors: [
                      AppColors.scrim.withValues(alpha: 0.9),
                      AppColors.scrim.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
