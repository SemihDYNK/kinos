import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Enveloppe une action Material avec l'anneau de focus du projet.
///
/// Le contrôle interne reste cliquable à la souris ; au clavier, c'est
/// [FocusRing] qui porte le focus et l'activation (Entrée, Espace, Select).
/// Ce montage reprend celui des rangées de réglages : un seul cadre visible,
/// jamais deux focus concurrents.
class LoginFocusAction extends StatelessWidget {
  const LoginFocusAction({
    required this.child,
    this.onActivate,
    this.autofocus = false,
    this.borderRadius = AppRadii.controlBorder,
    super.key,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final bool autofocus;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      onActivate: onActivate,
      autofocus: autofocus,
      borderRadius: borderRadius,
      child: ExcludeFocus(child: child),
    );
  }
}
