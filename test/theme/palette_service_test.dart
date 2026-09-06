import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/theme/palette_service.dart';

void main() {
  late PaletteService service;

  setUp(() {
    service = PaletteService(InMemoryPaletteCache());
  });

  // Régression : avant correction, le seuil de contraste du texte
  // secondaire (visait la luminance exacte d'AppColors.textSecondary,
  // ~4.6:1) rejetait la teinte de fond *entière* dès que le texte
  // secondaire échouait de justesse — la plupart des jaquettes retombaient
  // sur le repli neutre #141414, quel que soit le film.
  group('couleurs de jaquette typiques : la teinte est retenue', () {
    final samples = <String, Color>{
      'rouge affiche (action)': const Color(0xFFB0342A),
      'bleu nuit (SF)': const Color(0xFF1B2A4A),
      'orange chaud (comédie)': const Color(0xFFD98A2B),
      'vert forêt (thriller)': const Color(0xFF3A5A40),
      'or/beige (drame)': const Color(0xFFC2A46B),
      'rose/violet (romance)': const Color(0xFF8A4B8C),
      'cyan vif (animation)': const Color(0xFF2FB6C4),
      'jaune vif': const Color(0xFFE0C230),
    };

    for (final entry in samples.entries) {
      test(entry.key, () {
        final palette = service.fromSeed(entry.value);

        expect(palette.isFallback, isFalse,
            reason: 'la teinte ne doit pas retomber sur le repli neutre');
        expect(palette.tint, isNot(AppColors.heroFallback));

        expect(
          contrastRatio(AppColors.textPrimary, palette.tint),
          greaterThanOrEqualTo(TintLimits.minContrast),
        );
        expect(
          contrastRatio(palette.textSecondary, palette.tint),
          greaterThanOrEqualTo(TintLimits.minSecondaryContrast),
        );
      });
    }
  });

  group('bridage', () {
    test('une jaquette trop désaturée retombe sur le repli neutre', () {
      final palette = service
          .fromSeed(const Color(0xFF3A3A3A)); // gris pur, saturation nulle

      expect(palette.isFallback, isTrue);
      expect(palette.tint, AppColors.heroFallback);
      expect(palette.textSecondary, AppColors.textSecondary);
    });

    test(
        'la teinte retenue reste dans les bornes de luminance et de saturation',
        () {
      final palette = service
          .fromSeed(const Color(0xFFE0C230)); // jaune vif, hors bornes brut
      final hsl = HSLColor.fromColor(palette.tint);

      // Tolérance : la teinte est quantifiée en RGB 8 bits entre le clamp
      // HSL et cette relecture, `withLightness(0.16)` ne redonne donc pas
      // exactement 0.16 une fois reconverti.
      const epsilon = 0.01;
      expect(hsl.lightness,
          greaterThanOrEqualTo(TintLimits.minLightness - epsilon));
      expect(
          hsl.lightness, lessThanOrEqualTo(TintLimits.maxLightness + epsilon));
      expect(hsl.saturation,
          lessThanOrEqualTo(TintLimits.maxSaturation + epsilon));
    });
  });

  group('indépendance teinte / secondaire', () {
    // Les deux vérifications sont des décisions séparées : un échec du
    // texte secondaire ne doit jamais entraîner le repli de la teinte de
    // fond, qui reste valide indépendamment. Avec le bridage de luminance
    // actuel (0.06–0.16), la recherche de secondaire réussit en pratique
    // pour toute teinte produite par le service (cf. groupe précédent) ;
    // ce test verrouille la garantie elle-même — texte secondaire toujours
    // égal à AppColors.textSecondary ou d'un contraste ≥ 5:1 avec la
    // teinte, jamais un compromis silencieux entre les deux.
    test(
        'le texte secondaire est toujours soit conforme, soit le repli neutre — jamais un compromis',
        () {
      final samples = [
        const Color(0xFFB0342A),
        const Color(0xFF1B2A4A),
        const Color(0xFFD98A2B),
        const Color(0xFF3A5A40),
      ];

      for (final seed in samples) {
        final palette = service.fromSeed(seed);
        final matchesFallback =
            palette.textSecondary == AppColors.textSecondary;
        final meetsContrast =
            contrastRatio(palette.textSecondary, palette.tint) >=
                TintLimits.minSecondaryContrast;

        expect(matchesFallback || meetsContrast, isTrue);
      }
    });
  });
}
