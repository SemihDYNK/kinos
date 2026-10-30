import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';

class DecodeSizeImage extends MemoryImage {
  DecodeSizeImage(super.bytes);
  final decodedSizes = <ui.TargetImageSize>[];

  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    // ignore: deprecated_member_use
    return super.loadImage(key, (buffer, {getTargetSize}) async {
      final codec = await decode(buffer, getTargetSize: getTargetSize);
      return RecordingCodec(codec, decodedSizes);
    });
  }
}

class RecordingCodec implements ui.Codec {
  RecordingCodec(this.delegate, this.sizes);
  final ui.Codec delegate;
  final List<ui.TargetImageSize> sizes;
  @override
  int get frameCount => delegate.frameCount;
  @override
  int get repetitionCount => delegate.repetitionCount;
  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final frame = await delegate.getNextFrame();
    sizes.add(ui.TargetImageSize(
        width: frame.image.width, height: frame.image.height));
    return frame;
  }

  @override
  void dispose() => delegate.dispose();
}

void main() {
  testWidgets('palette actually decodes a thumbnail instead of the full banner',
      (tester) async {
    final recording = ui.PictureRecorder();
    Canvas(recording).drawColor(const Color(0xFFB0342A), BlendMode.src);
    final result = await tester.runAsync(() async {
      final picture = recording.endRecording();
      final image = await picture.toImage(1200, 600);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final provider = DecodeSizeImage(Uint8List.sublistView(png!));
      final palette = await PaletteService(InMemoryPaletteCache())
          .forItem(itemId: 'large-banner', image: provider);
      return (provider, palette);
    });
    expect(result!.$1.decodedSizes.last.width,
        lessThanOrEqualTo(TintLimits.thumbSize.width));
    expect(result.$1.decodedSizes.last.height,
        lessThanOrEqualTo(TintLimits.thumbSize.height));
    expect(result.$2.isFallback, isFalse);
  });

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
      // HSL et cette relecture, `withLightness(maxLightness)` ne redonne
      // donc pas exactement cette valeur une fois reconvertie.
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
    // actuel (TintLimits.minLightness–maxLightness), la recherche de
    // secondaire réussit en pratique pour toute teinte produite par le
    // service (cf. groupe précédent) ;
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
