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
/// Le bloc titre (posé PAR-DESSUS ce calque par l'appelant, cf.
/// `_TitleBlock`/`HeroCarousel`) reste donc sur une image pleinement
/// visible sur toute sa hauteur — le voile ne commence à agir qu'APRÈS
/// [holdUntil], jamais dans la zone du titre lui-même.
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

  /// Hauteur, depuis le haut de ce calque, jusqu'à laquelle l'image reste
  /// pleinement nette (aucune teinte, aucune dissolution) : la hauteur du
  /// bloc titre posé par-dessus (toujours présent, contrairement au
  /// contenu qui le suit — résumé, casting, "Continuer à regarder"...).
  /// Le voile (montée de teinte, puis dissolution) ne commence qu'APRÈS
  /// ce point, jamais dans la zone du titre lui-même.
  final double holdUntil;

  /// Distance, comptée à partir de [holdUntil], sur laquelle la teinte
  /// monte progressivement jusqu'à pleinement opaque. Par défaut 200px —
  /// le réglage validé sur le bandeau film/série.
  final double rampDistance;

  /// Distance, comptée après la fin de la montée de teinte (soit
  /// `holdUntil + rampDistance`), sur laquelle la teinte, déjà pleinement
  /// montée, se dissout ensuite vers la transparence totale. Par défaut
  /// 150px, même origine que [rampDistance].
  ///
  /// `holdUntil + rampDistance + resolveDistance` doit rester nettement
  /// inférieur à la hauteur réelle de ce calque (posée par l'appelant via
  /// `SliverPositioned`) — sous peine de voir la dissolution se faire
  /// couper avant d'avoir fini, silencieusement bridée à 1.0 par le
  /// `clamp` ci-dessous.
  final double resolveDistance;

  const FadingHeroBackdrop({
    required this.image,
    required this.heroTint,
    required this.holdUntil,
    this.rampDistance = 200.0,
    this.resolveDistance = 150.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // La hauteur réelle de ce calque vient de ses propres contraintes
        // (posé via SliverPositioned côté appelant) — pas d'un paramètre
        // séparé qui risquerait de diverger de la taille effective.
        final height = constraints.maxHeight;
        final tintOpaqueAt = holdUntil + rampDistance;
        final dissolveAt = tintOpaqueAt + resolveDistance;
        final holdUntilFraction = (holdUntil / height).clamp(0.0, 1.0);
        final tintOpaqueFraction = (tintOpaqueAt / height).clamp(0.0, 1.0);
        final dissolveFraction = (dissolveAt / height).clamp(0.0, 1.0);
        // Le voile de lisibilité vertical (cf. calque e) monte vers son
        // maximum sur les derniers 45% de la zone du titre — même
        // proportion que l'ancien calque local de HeroCarousel/_Banner,
        // appliquée ici à `holdUntil` plutôt qu'à la hauteur totale de ce
        // calque (bien plus grande) : la lisibilité se joue au niveau du
        // titre, pas sur toute la hauteur de l'image.
        final scrimRiseStartFraction =
            ((holdUntil * 0.55) / height).clamp(0.0, 1.0);

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, tintOpaqueFraction, dissolveFraction],
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
              // c. Teinte qui monte progressivement à partir de
              // `holdUntil` (image nue jusque-là) jusqu'à pleinement
              // teintée (mais encore opaque) à `tintOpaqueFraction`. La
              // dissolution vers la transparence totale est le rôle du
              // ShaderMask ci-dessus, pas de ce calque.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, holdUntilFraction, tintOpaqueFraction],
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
              // e. Dégradé vertical — contraste pour le texte en bas
              // (titre, métadonnées, boutons), qui vit dans les derniers
              // pixels de la zone `holdUntil`.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [scrimRiseStartFraction, holdUntilFraction],
                    colors: [
                      AppColors.scrim.withValues(alpha: 0),
                      AppColors.scrim.withValues(alpha: 0.75),
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
