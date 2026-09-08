import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Force la densité "desk", quel que soit le réglage global — le module
/// *Arr est bureau uniquement : pas de mode salon, pas de navigation
/// télécommande, un tableau à dix colonnes y serait illisible. La
/// navigation clavier (Tab + flèches) reste inchangée, [FocusRing] et les
/// tailles de cible interactive suivent [AppTokens.density] comme partout
/// ailleurs — seule cette valeur est figée ici.
class ArrDesktopScope extends StatelessWidget {
  final Widget child;

  const ArrDesktopScope({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    if (tokens == null || tokens.density == AppDensity.desk) return child;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values
              .where((extension) => extension is! AppTokens),
          tokens.copyWith(density: AppDensity.desk),
        ],
      ),
      child: child,
    );
  }
}
