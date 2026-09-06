import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import 'app_theme.dart';

/// Extraction de la dominante d'une jaquette pour teinter le bandeau d'accueil.
///
/// Règles du projet :
///   - seul le bandeau se teinte, jamais la zone principale ;
///   - luminance bridée entre 0.06 et 0.22 ;
///   - saturation plafonnée à 0.40 ;
///   - contraste ≥ 4.5:1 entre la teinte et le texte principal, vérifié et
///     non supposé ; sous ce seuil, repli complet ;
///   - contraste ≥ 5.0:1 entre la teinte et le texte secondaire teinté ;
///     sous ce seuil, seul le secondaire retombe sur
///     [AppColors.textSecondary] — la teinte, elle, reste valide.

// ---------------------------------------------------------------------------
// Résultat
// ---------------------------------------------------------------------------

@immutable
class HeroPalette {
  const HeroPalette({
    required this.tint,
    required this.textSecondary,
    required this.isFallback,
  });

  /// Fond du bandeau, déjà bridé.
  final Color tint;

  /// Gris secondaire décalé en teinte. [AppColors.textSecondary] si la
  /// teinte de fond est valide mais qu'aucune variante teintée du
  /// secondaire n'atteint un contraste suffisant avec elle — la teinte de
  /// fond n'a pas à payer l'échec d'un texte secondaire (cf. [_buildFrom]).
  final Color textSecondary;

  /// Vrai si la teinte de fond elle-même est le repli neutre (extraction
  /// échouée, jaquette trop désaturée, ou contraste insuffisant avec le
  /// texte principal). Un repli du seul texte secondaire ne compte pas :
  /// [tint] reste alors la vraie dominante extraite.
  final bool isFallback;

  static const fallback = HeroPalette(
    tint: AppColors.heroFallback,
    textSecondary: AppColors.textSecondary,
    isFallback: true,
  );

  @override
  bool operator ==(Object other) =>
      other is HeroPalette &&
      other.tint == tint &&
      other.textSecondary == textSecondary;

  @override
  int get hashCode => Object.hash(tint, textSecondary);
}

// ---------------------------------------------------------------------------
// Contraintes
// ---------------------------------------------------------------------------

abstract final class TintLimits {
  /// Bornes de luminance HSL du fond.
  static const minLightness = 0.06;
  static const maxLightness = 0.22;

  /// Plafond de saturation. Au-delà, on lit une couleur et non une ambiance.
  static const maxSaturation = 0.40;

  /// En dessous, la jaquette est trop désaturée : le résultat serait un
  /// gris-brun indéfinissable. Mieux vaut le repli neutre.
  static const minUsableSaturation = 0.05;

  /// Seuil WCAG AA pour du texte normal.
  static const minContrast = 4.5;

  /// Seuil visé pour le texte secondaire *contre la teinte*, plus haut que
  /// [minContrast] : la recherche de [PaletteService._shiftedSecondary]
  /// converge près de sa cible, jamais pile dessus — viser 4.5 revenait à
  /// échouer la vérification presque à chaque fois.
  static const minSecondaryContrast = 5.0;

  /// Taille de la vignette analysée. Ne jamais analyser l'image pleine.
  static const thumbSize = Size(100, 150);

  /// Peu de couleurs suffit pour une dominante, et c'est bien plus rapide.
  static const maxColorCount = 12;
}

// ---------------------------------------------------------------------------
// Cache — interface à brancher sur la table Drift `palette_cache`
// ---------------------------------------------------------------------------

abstract interface class PaletteCacheStore {
  Future<int?> read(String itemId);
  Future<void> write(String itemId, int argb);
}

/// Repli mémoire, utile en test ou tant que la table n'est pas branchée.
class InMemoryPaletteCache implements PaletteCacheStore {
  final _map = <String, int>{};

  @override
  Future<int?> read(String itemId) async => _map[itemId];

  @override
  Future<void> write(String itemId, int argb) async => _map[itemId] = argb;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class PaletteService {
  PaletteService(this._cache);

  final PaletteCacheStore _cache;

  /// Anti-doublon : plusieurs widgets peuvent demander le même item en même
  /// temps pendant le défilement.
  final _inFlight = <String, Future<HeroPalette>>{};

  /// Renvoie la palette du bandeau pour [itemId].
  ///
  /// [seedColor] permet de passer la couleur moyenne du blurhash renvoyé par
  /// Jellyfin : elle sert d'affichage immédiat avant que la jaquette soit
  /// téléchargée. Elle passe par le même bridage.
  Future<HeroPalette> forItem({
    required String itemId,
    required ImageProvider image,
  }) {
    return _inFlight.putIfAbsent(itemId, () async {
      try {
        final cached = await _cache.read(itemId);
        if (cached != null) return _buildFrom(Color(cached));

        final extracted = await _extract(image);
        if (extracted == null) return HeroPalette.fallback;

        await _cache.write(itemId, extracted.toARGB32());
        return _buildFrom(extracted);
      } catch (_) {
        return HeroPalette.fallback;
      } finally {
        _inFlight.remove(itemId);
      }
    });
  }

  /// Version synchrone à partir d'une couleur déjà connue (blurhash).
  HeroPalette fromSeed(Color seed) => _buildFrom(seed);

  // -------------------------------------------------------------------------

  Future<Color?> _extract(ImageProvider image) async {
    final generator = await PaletteGenerator.fromImageProvider(
      image,
      size: TintLimits.thumbSize,
      maximumColorCount: TintLimits.maxColorCount,
    );

    // DarkMuted d'abord : c'est la seule cible pensée pour un fond sombre.
    // Les autres sont trop lumineuses et sortent des bornes après bridage.
    return generator.darkMutedColor?.color ??
        generator.darkVibrantColor?.color ??
        generator.dominantColor?.color;
  }

  HeroPalette _buildFrom(Color raw) {
    final hsl = HSLColor.fromColor(raw);

    // Jaquette trop désaturée : le repli neutre est plus beau qu'un gris sale.
    if (hsl.saturation < TintLimits.minUsableSaturation) {
      return HeroPalette.fallback;
    }

    final tint = hsl
        .withSaturation(hsl.saturation.clamp(0.0, TintLimits.maxSaturation))
        .withLightness(
          hsl.lightness.clamp(TintLimits.minLightness, TintLimits.maxLightness),
        )
        .toColor();

    // Vérification, pas supposition.
    if (contrastRatio(AppColors.textPrimary, tint) < TintLimits.minContrast) {
      return HeroPalette.fallback;
    }

    // La teinte de fond est valide à ce stade — elle est retenue même si le
    // texte secondaire teinté n'atteint pas son propre seuil : les deux
    // décisions sont indépendantes, l'échec de l'un ne doit pas jeter
    // l'autre, qui était pourtant bon.
    final secondary = _shiftedSecondary(hsl.hue, tint);
    final effectiveSecondary =
        contrastRatio(secondary, tint) >= TintLimits.minSecondaryContrast
            ? secondary
            : AppColors.textSecondary;

    return HeroPalette(
      tint: tint,
      textSecondary: effectiveSecondary,
      isFallback: false,
    );
  }

  /// Cherche la clarté la plus basse (donc la plus proche de la teinte, la
  /// moins "délavée") d'une variante teintée du gris secondaire qui atteint
  /// [TintLimits.minSecondaryContrast] contre [tint]. Le contraste croît
  /// avec la clarté à teinte/saturation fixes : recherche dichotomique.
  Color _shiftedSecondary(double hue, Color tint) {
    HSLColor candidateAt(double lightness) =>
        HSLColor.fromAHSL(1.0, hue, 0.12, lightness);

    // Même blanc pur n'atteint pas le seuil (teinte de fond anormalement
    // claire) : c'est le mieux qu'on puisse faire, on ne cherche pas plus.
    final brightest = candidateAt(1.0).toColor();
    if (contrastRatio(brightest, tint) < TintLimits.minSecondaryContrast) {
      return brightest;
    }

    var low = 0.0; // contraste connu insuffisant
    var high = 1.0; // contraste connu suffisant
    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      final contrast = contrastRatio(candidateAt(mid).toColor(), tint);
      if (contrast >= TintLimits.minSecondaryContrast) {
        high = mid;
      } else {
        low = mid;
      }
    }

    return candidateAt(high).toColor();
  }
}

// ---------------------------------------------------------------------------
// Contraste — WCAG 2.1
// ---------------------------------------------------------------------------

double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : _pow((v + 0.055) / 1.055, 2.4);

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _pow(double x, double exp) => math.pow(x, exp).toDouble();
