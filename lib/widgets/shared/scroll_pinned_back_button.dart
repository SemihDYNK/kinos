import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

/// Place du bouton retour dans l'en-tête d'une page (icône, marges et anneau
/// de focus compris).
const backButtonSlot = 48.0;

/// Page avec un bouton « Retour » qui reste visible : à sa place dans
/// l'en-tête au repos, il glisse dans le coin de la fenêtre, sur un fond
/// dépoli, dès que la page défile.
class ScrollPinnedBackButton extends StatefulWidget {
  const ScrollPinnedBackButton(
      {required this.restLeft,
      required this.child,
      this.restTop = AppSpacing.xl,
      this.frostedAtRest = false,
      this.onBack,
      super.key});

  /// Position du bouton au repos, dans l'en-tête.
  final double restLeft;
  final double restTop;

  /// Fond dépoli dès le repos, quand le bouton est posé sur une image
  /// (fiche d'un film) plutôt que sur le fond uni de la page : le même
  /// verre que lorsqu'il est épinglé, pour qu'il ne change pas de
  /// transparence en se déplaçant.
  final bool frostedAtRest;

  /// Action de retour ; par défaut, `maybePop` du routeur.
  final VoidCallback? onBack;
  final Widget child;

  @override
  State<ScrollPinnedBackButton> createState() => _ScrollPinnedBackButtonState();
}

class _ScrollPinnedBackButtonState extends State<ScrollPinnedBackButton> {
  static const _threshold = 48.0;
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > _threshold;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.enabled(context)
        ? AppDurations.navigationExpand
        : Duration.zero;
    final button = Tooltip(
      message: 'Retour · Échap',
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: widget.onBack ?? () => context.router.maybePop(),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: Icon(Icons.arrow_back, semanticLabel: 'Retour'),
        ),
      ),
    );
    return Stack(children: [
      NotificationListener<ScrollNotification>(
          onNotification: _onScroll, child: widget.child),
      AnimatedPositioned(
        duration: duration,
        curve: AppMotion.navigationReveal,
        // Centré sur la capsule latérale repliée.
        left: _scrolled
            ? MediaQuery.paddingOf(context).left +
                AppNavigation.inset +
                (AppNavigation.collapsedWidth - backButtonSlot) / 2
            : widget.restLeft,
        // Centré sur la capsule du haut.
        top: _scrolled
            ? MediaQuery.paddingOf(context).top +
                AppSpacing.sm +
                (AppTopNavigation.capsuleHeight - backButtonSlot) / 2
            : widget.restTop,
        child: _scrolled || widget.frostedAtRest
            ? FrostedSurface(
                color: AppNavigation.surface,
                borderRadius: AppRadii.controlBorder,
                child: button)
            : button,
      ),
    ]);
  }
}
