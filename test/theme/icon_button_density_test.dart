import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';

/// Aucun bouton de `desktopBottomBar` (barre du bas du lecteur) ne
/// fixe sa propre `minimumSize` — la cible tactile vient entièrement
/// du thème global (`iconButtonTheme`). Ce test vérifie directement ce
/// mécanisme plutôt que de monter le lecteur complet (coût prohibitif :
/// `PlaybackModel` a plusieurs méthodes `UnimplementedError()`,
/// réservées à ses sous-classes concrètes) — la garantie "cibles assez
/// grandes en mode salon" tient pour CHAQUE `IconButton` de la barre
/// tant qu'aucun ne surcharge `minimumSize` localement (vérifié : aucun
/// ne le fait dans `video_player_controls.dart`).
void main() {
  test('mode bureau : cible tactile = AppDensity.desk.minTarget', () {
    final theme = buildAppTheme(density: AppDensity.desk);
    final minimumSize =
        theme.iconButtonTheme.style?.minimumSize?.resolve({});

    expect(minimumSize, Size.square(AppDensity.desk.minTarget));
  });

  test('mode salon : cible tactile = AppDensity.couch.minTarget (agrandie)',
      () {
    final theme = buildAppTheme(density: AppDensity.couch);
    final minimumSize =
        theme.iconButtonTheme.style?.minimumSize?.resolve({});

    expect(minimumSize, Size.square(AppDensity.couch.minTarget));
    expect(AppDensity.couch.minTarget, greaterThan(AppDensity.desk.minTarget));
  });
}
