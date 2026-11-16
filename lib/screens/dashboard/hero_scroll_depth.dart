import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:kinos/theme/app_theme.dart';

/// Plan du bandeau d'accueil dans l'effet de profondeur au défilement.
enum HeroDepthLayer {
  /// L'image : elle ne suit le contenu qu'à [AppMotion.heroParallax] de sa
  /// vitesse et s'éteint à mesure que le bandeau sort de l'écran.
  image,

  /// Le texte : il défile normalement et s'efface en approchant du haut de
  /// l'écran.
  text,
}

/// Profondeur du bandeau d'accueil, liée au défilement (aucune minuterie).
///
/// L'image reste en arrière pendant que le contenu passe par-dessus, puis
/// s'éteint jusqu'au fond teinté de la section ; le texte, au premier plan,
/// s'efface avant de passer sous le haut de la fenêtre.
///
/// Le mouvement suit la position du défilement : il reste actif pendant la
/// navigation au clavier (le couper au milieu d'un défilement ferait sauter
/// l'image). Seuls « réduire les animations » et la navigation accessible
/// le désactivent.
class HeroScrollDepth extends StatefulWidget {
  const HeroScrollDepth({required this.layer, required this.child, super.key});
  final HeroDepthLayer layer;
  final Widget child;

  @override
  State<HeroScrollDepth> createState() => _HeroScrollDepthState();
}

class _HeroScrollDepthState extends State<HeroScrollDepth> {
  ScrollPosition? _position;

  /// Distance du haut de ce plan sous le haut de la zone visible, en
  /// pixels : positive tant qu'il est entièrement à l'écran.
  final _top = ValueNotifier<double?>(null);
  double _height = 0;

  /// [_top] au repos (défilement à zéro).
  double _rest = 0;

  bool get _still =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = _still ? null : Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_measure);
      _position = position?..addListener(_measure);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(HeroScrollDepth oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Une mise en page nouvelle (diapo, fenêtre redimensionnée) peut
    // déplacer le plan sans défilement.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Mesuré hors de la mise en page (écouteur, fin d'image) : le carrousel
  /// est construit dans un LayoutBuilder, où lire la taille d'une boîte
  /// déclencherait une assertion.
  void _measure() {
    if (!mounted) return;
    final position = _position;
    final box = context.findRenderObject();
    if (position == null ||
        !position.hasPixels ||
        box is! RenderBox ||
        !box.attached ||
        !box.hasSize) {
      _top.value = null;
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    _height = box.size.height;
    // Position de défilement à laquelle le haut de ce plan touche le haut
    // de la zone visible.
    final reveal = viewport.getOffsetToReveal(box, 0).offset;
    _rest = reveal;
    _top.value = reveal - position.pixels;
  }

  @override
  void dispose() {
    _position?.removeListener(_measure);
    _top.dispose();
    super.dispose();
  }

  // Structure fixe (découpe, translation, opacité) quelle que soit la
  // position : changer d'arbre au passage d'un seuil reconstruirait le
  // contenu et lui ferait perdre le focus.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double?>(
        valueListenable: _top,
        child: widget.child,
        builder: (context, top, child) {
          final measured = top != null && _height > 0;
          return switch (widget.layer) {
            HeroDepthLayer.image => _image(measured ? top : 0, child!),
            HeroDepthLayer.text =>
              Opacity(opacity: measured ? _textOpacity(top) : 1, child: child),
          };
        },
      );

  Widget _image(double top, Widget child) {
    final scrolled = (-top).clamp(0.0, _height);
    final fade = scrolled == 0
        ? 0.0
        : Curves.easeOut.transform(
            (scrolled / (_height * AppMotion.heroScrollFadeEnd))
                .clamp(0.0, 1.0));
    return ClipRect(
      child: Transform.translate(
        offset: Offset(0, scrolled * AppMotion.heroParallax),
        child: Opacity(opacity: 1 - fade, child: child),
      ),
    );
  }

  /// Opaque tant que le texte est à [AppMotion.heroTextFadeLead] du haut ou
  /// plus bas ; effacé quand sa moitié est passée au-dessus. Un texte qui
  /// commence déjà plus haut que ce seuil (grand texte, fenêtre basse) part
  /// de sa position de repos : il n'est jamais estompé sans défilement.
  double _textOpacity(double top) {
    final lead =
        _rest.clamp(double.negativeInfinity, AppMotion.heroTextFadeLead);
    final half = _height / 2;
    if (lead + half <= 0) return 1;
    return ((top + half) / (lead + half)).clamp(0.0, 1.0);
  }
}
