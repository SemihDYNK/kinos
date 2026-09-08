import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';

/// Teinte courante du bandeau d'accueil.
///
/// Seul le bandeau se teinte — jamais la zone principale, cf. la règle du
/// projet. L'écran qui affiche le bandeau (tableau de bord) met cette valeur
/// à jour via [PaletteService.forItem] / [PaletteService.fromSeed] ; tout
/// échec ou absence de sélection retombe sur [HeroPalette.fallback].
final heroPaletteProvider =
    StateProvider<HeroPalette>((ref) => HeroPalette.fallback);

/// Densité de l'interface : bureau ou salon (double densité, même code).
///
/// Dérivée du lean-back mode déjà résolu au démarrage
/// (`ArgumentsModel.leanBackMode` : argument CLI, Android TV, ou fenêtre).
/// Une seule source de vérité — pas de réglage dupliqué dans les préférences.
final appDensityProvider = Provider<AppDensity>((ref) {
  final leanBack =
      ref.watch(argumentsStateProvider.select((value) => value.leanBackMode));
  return leanBack ? AppDensity.couch : AppDensity.desk;
});

/// Thème unique de l'app — sombre uniquement, pas de variante claire.
///
/// Recalculé à chaque changement de densité ou de teinte de bandeau ;
/// [AnimatedTheme] (posé dans `main.dart`) interpole la transition grâce à
/// [AppTokens.lerp], notamment sur [AppTokens.heroTint].
final appThemeProvider = Provider<ThemeData>((ref) {
  final density = ref.watch(appDensityProvider);
  final palette = ref.watch(heroPaletteProvider);
  return buildAppTheme(
    density: density,
    heroTint: palette.tint,
    heroTextSecondary: palette.textSecondary,
  );
});
