import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Un élément qui arrive après coup (données chargées en différé) entre en
/// fondu avec une légère montée au lieu de surgir.
///
/// Ce qui est déjà là quand la page s'ouvre (la transition de route n'est
/// pas terminée) s'affiche tel quel : la page arrive en un seul geste, sans
/// une seconde animation par-dessus.
class AppearIn extends StatefulWidget {
  const AppearIn({required this.child, super.key});
  final Widget child;

  @override
  State<AppearIn> createState() => _AppearInState();
}

class _AppearInState extends State<AppearIn>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: AppDurations.unroll);
  late final _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (!AppMotion.enabled(context)) {
      _controller.value = 1;
      return;
    }
    // À la toute première image, l'animation de la route n'est pas encore
    // branchée (elle se dit terminée) : on regarde à l'image suivante si la
    // page est en train de s'ouvrir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context)?.animation;
      if (route != null && !route.isCompleted) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset(0, AppMotion.heroTextTravel * (1 - _curve.value)),
            child: child,
          ),
        ),
      );
}

/// [AnimatedSize] aux réglages du projet, qui suit en douceur les
/// changements de taille de son enfant.
///
/// Sans mouvement, la durée tombe à une milliseconde, jamais à zéro : une
/// durée nulle ferait se terminer l'animation pendant sa propre mise en
/// page, ce que Flutter refuse. Le widget reste toujours en place : la
/// navigation au clavier coupe le mouvement, et retirer l'[AnimatedSize] à
/// ce moment reconstruirait tout le sous-arbre (et perdrait le focus).
class SmoothSize extends StatelessWidget {
  const SmoothSize(
      {required this.child,
      this.alignment = Alignment.topLeft,
      this.clipBehavior = Clip.hardEdge,
      super.key});
  final Widget child;
  final AlignmentGeometry alignment;
  final Clip clipBehavior;

  static const _instant = Duration(milliseconds: 1);

  @override
  Widget build(BuildContext context) => AnimatedSize(
      duration: AppMotion.enabled(context) ? AppDurations.unroll : _instant,
      curve: AppMotion.easeOut,
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: child);
}
