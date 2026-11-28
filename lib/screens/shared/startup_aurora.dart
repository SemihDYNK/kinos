import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

import 'package:kinos/theme/app_theme.dart';

/// Le fond de l'intro, au clap.
enum StartupBackdrop {
  /// La goutte : l'onde part du K et découvre le liquide du film.
  drop,

  /// L'ancienne aurore : des taches de couleur floues.
  aurora,
}

/// `KINOS_STARTUP_BACKDROP=aurora` (mise au point) ; la goutte sinon.
StartupBackdrop startupBackdropFrom(Map<String, String> environment) =>
    environment['KINOS_STARTUP_BACKDROP'] == 'aurora'
        ? StartupBackdrop.aurora
        : StartupBackdrop.drop;

final _log = Logger('StartupAurora');

/// Aurore de l'intro longue : de grandes taches de couleur floues, tirées
/// de la dominante du film du bandeau, qui dérivent lentement et se
/// fondent. Elle naît au clap et reste derrière le K jusqu'à ce que le
/// faisceau ouvre sur ce même film.
///
/// Son horloge est partagée : l'écran de démarrage puis le rideau de
/// l'ouverture la peignent au même instant de son mouvement, sans saut.
abstract final class StartupAurora {
  static final _clock = Stopwatch();

  // Profil de chaque tache, du centre au bord : une courbe en S.
  static const _falloffStops = [0.0, .2, .4, .6, .8, 1.0];
  static const _falloff = [1.0, .9, .65, .35, .1, 0.0];

  /// Temps de l'aurore, en secondes, mis à jour à chaque image par
  /// [StartupAuroraTicker].
  static final time = ValueNotifier<double>(0);

  /// Le fond choisi pour cette session.
  static StartupBackdrop backdrop = kIsWeb
      ? StartupBackdrop.aurora
      : startupBackdropFrom(Platform.environment);

  static ui.FragmentProgram? _liquid;
  static Future<void>? _loading;

  /// Charge le shader du fond liquide (une fois). Sans lui (échec, ou pas
  /// encore prêt au clap), l'aurore prend le relais.
  static Future<void> loadLiquid() => _loading ??= _load();

  static Future<void> _load() async {
    if (backdrop == StartupBackdrop.aurora) return;
    try {
      _liquid =
          await ui.FragmentProgram.fromAsset('shaders/startup_liquid.frag');
    } catch (error) {
      _log.warning('Fond liquide indisponible : $error');
    }
  }

  /// Le fond liquide est prêt et choisi.
  static bool get liquid =>
      backdrop != StartupBackdrop.aurora && _liquid != null;

  /// Temps de l'aurore au clap ; `null` tant qu'il n'a pas eu lieu.
  static double? clapAt;

  /// Secondes depuis le clap. Sans clap vu (intro passée), un clap depuis
  /// longtemps passé : la lumière est posée, les lettres chargées.
  static double get wave =>
      clapAt == null ? AppMotion.startupLiquidCalm : time.value - clapAt!;

  static Color _shade(Color tint, (double, double, double) spec) {
    final base = HSLColor.fromColor(tint);
    return base
        .withHue((base.hue + spec.$1) % 360)
        .withSaturation(spec.$2)
        .withLightness(spec.$3)
        .toColor();
  }

  /// L'encre et le cœur chaud de la lumière, tirés de la dominante.
  static List<Color> liquidColorsFor(Color tint) => [
        _shade(tint, AppMotion.startupLiquidInk),
        _shade(tint, AppMotion.startupLiquidHot),
      ];

  /// La lumière en attendant la dominante : des gris.
  static List<Color> get liquidNeutral => [
        for (final lightness in AppMotion.startupLiquidNeutralLightness)
          HSLColor.fromAHSL(1, 0, 0, lightness).toColor(),
      ];

  /// Le haut et le bas des lettres chargées, tirés de la dominante.
  static List<Color> letterColorsFor(Color tint) => [
        _shade(tint, AppMotion.startupLetterTop),
        _shade(tint, AppMotion.startupLetterBottom),
      ];

  /// Lettres sans dominante : blanches.
  static const letterNeutral = [AppColors.textPrimary, AppColors.textPrimary];

  /// Les couleurs des lettres chargées, tenues à jour par le fond du clap
  /// (elles suivent l'arrivée de la dominante).
  static List<Color> letters = letterNeutral;

  /// Charge des lettres (0 : blanches, 1 : aux couleurs du film), d'après
  /// le temps depuis le clap.
  static double get charge => Curves.easeInOut.transform(((wave -
              AppMotion.startupLetterChargeFrom) /
          (AppMotion.startupLetterChargeTo - AppMotion.startupLetterChargeFrom))
      .clamp(0.0, 1.0));

  /// Le pinceau des lettres de la signature (repère du signe, 256 unités) :
  /// blanc, puis le dégradé des couleurs du film à mesure qu'elles se
  /// chargent ; en retenue avant le clap, pleinement éclairées après.
  static Paint letterPaint(double alpha) {
    final amount = charge;
    // Avant le clap, le K s'éclaire en retenue ; au clap, tout son éclat.
    final burst = wave < 0
        ? 0.0
        : Curves.easeOut
            .transform((wave / AppMotion.startupLetterBurst).clamp(0.0, 1.0));
    final level = ui.lerpDouble(AppMotion.startupLetterRestraint, 1, burst)!;
    if (amount <= 0) {
      return Paint()
        ..color =
            Color.lerp(AppColors.background, AppColors.textPrimary, level)!
                .withValues(alpha: alpha);
    }
    Color stop(Color c) => Color.lerp(AppColors.background,
            Color.lerp(AppColors.textPrimary, c, amount)!, level)!
        .withValues(alpha: alpha);
    return Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 15), const Offset(0, 241),
          [stop(letters[0]), stop(letters[1])]);
  }

  /// Secondes de la scène (version longue) depuis son début, d'après le
  /// temps depuis le clap.
  static double storyOf(double wave) =>
      wave +
      AppMotion.startupIntroAssemblyEnd *
          AppMotion.startupIntroClap *
          AppDurations.startupIntro.inMicroseconds /
          1e6;

  /// La galerie de verre à l'instant [story] (secondes de la scène) :
  /// profondeur et décalage de la caméra, front de la lumière dans les
  /// arêtes, éclairage du K, reflet d'objectif et sortie du noir.
  static ({
    double depth,
    double side,
    double ignite,
    double lit,
    double flare,
    double fade,
  }) galleryAt(double story) {
    double clamp01(double x) => x.clamp(0.0, 1.0);
    double out(double x) => Curves.easeOutCubic.transform(clamp01(x));
    final travel = Curves.easeInOutCubic
        .transform(clamp01(story / AppMotion.startupGalleryDollyTime));
    final clap = storyOf(0);
    return (
      depth: AppMotion.startupGalleryDolly * travel,
      side: AppMotion.startupGalleryArc *
          math.sin(story * AppMotion.startupGalleryArcRate) *
          (1 - travel),
      ignite: -1 +
          AppMotion.startupGalleryIgniteDepth *
              out((story - AppMotion.startupGalleryIgniteFrom) /
                  AppMotion.startupGalleryIgniteTime),
      lit: out((story - AppMotion.startupGalleryLitFrom) /
          AppMotion.startupGalleryLitTime),
      flare: story > clap
          ? math.exp(-(story - clap) * AppMotion.startupGalleryFlare)
          : 0.0,
      fade: out(story / AppMotion.startupGalleryFadeIn),
    );
  }

  /// Échelle du K au fond de la galerie : il grandit à mesure que la
  /// caméra approche, jusqu'à sa taille finale.
  static double markScale(double story) => (AppMotion.startupGalleryMarkRest /
          (AppMotion.startupGalleryMarkDepth - galleryAt(story).depth))
      .clamp(0.0, 1.0);

  /// Peint la lumière du clap sur [rect] : [colors] (encre, cœur), [wave]
  /// secondes après le clap, les traînées convergeant vers [centre] et les
  /// rayons ([rays], de 0 à 1) à travers les lettres que [paintMask] dessine
  /// (en coordonnées de l'écran), et le verre irisé autour de [tint]. Comme l'aurore, dans une petite image
  /// agrandie à l'écran.
  static void paintLiquid(Canvas canvas, Rect rect,
      {required List<Color> colors,
      required double wave,
      required Offset centre,
      required void Function(Canvas canvas) paintMask,
      double rays = 1,
      Color? tint,
      double intensity = 1,
      BlendMode blendMode = BlendMode.srcOver}) {
    final program = _liquid;
    if (rect.isEmpty || program == null) return;
    final scale =
        math.min(1.0, AppMotion.startupLiquidResolution / rect.longestSide);
    final width = math.max(1, (rect.width * scale).ceil());
    final height = math.max(1, (rect.height * scale).ceil());

    // Le pochoir des lettres, à la taille de l'image, flouté par Flutter
    // (un vrai flou ; échantillonné à quelques décalages dans le shader,
    // il laissait voir des copies des lettres) : un flou léger pour leur
    // brillance et leurs rayons, un flou large pour la lumière qu'elles
    // renvoient sur le verre.
    ui.Image blurred(double sigma) {
      final recorder = ui.PictureRecorder();
      final layer = Canvas(recorder)
        ..saveLayer(
            null,
            Paint()
              ..imageFilter =
                  ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
      layer
        ..scale(scale)
        ..translate(-rect.left, -rect.top);
      paintMask(layer);
      layer.restore();
      final picture = recorder.endRecording();
      final image = picture.toImageSync(width, height);
      picture.dispose();
      return image;
    }

    final glow = blurred(height * AppMotion.startupLightGlowBlur);
    final spill = blurred(height * AppMotion.startupLightSpillBlur);

    final shader = program.fragmentShader();
    var i = 0;
    void set(double value) => shader.setFloat(i++, value);
    void color(Color c) {
      set(c.r);
      set(c.g);
      set(c.b);
    }

    set(width.toDouble());
    set(height.toDouble());
    set(time.value);
    set(wave);
    set(intensity);
    set((centre.dx - rect.left) * scale);
    set((centre.dy - rect.top) * scale);
    set(rays);
    color(AppColors.background);
    for (final c in colors) {
      color(c);
    }
    set(AppMotion.startupLiquidGrain);
    // Les irisations du verre suivent la dominante ; sans elle, gris.
    set(tint == null ? 0 : HSLColor.fromColor(tint).hue / 360);
    set(tint == null ? 0 : 1);
    final shot = galleryAt(storyOf(wave));
    set(shot.depth);
    set(shot.side);
    set(shot.ignite);
    set(shot.lit);
    set(shot.flare);
    set(shot.fade);
    shader.setImageSampler(0, glow, filterQuality: FilterQuality.medium);
    shader.setImageSampler(1, spill, filterQuality: FilterQuality.medium);

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    shader.dispose();
    glow.dispose();
    spill.dispose();
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        rect,
        Paint()
          ..blendMode = blendMode
          ..filterQuality = FilterQuality.medium);
    image.dispose();
  }

  static void _tick() {
    if (!_clock.isRunning) _clock.start();
    time.value = _clock.elapsedMicroseconds / 1e6;
  }

  /// Les couleurs des taches : la dominante et des teintes voisines,
  /// plus saturées, de clartés contrastées. Une dominante neutre (le
  /// repli) reste dans des gris.
  static List<Color> colorsFor(Color tint) {
    final base = HSLColor.fromColor(tint);
    Color shade(double hueShift, double lightness, double saturation) => base
        .withHue((base.hue + hueShift) % 360)
        .withLightness(lightness)
        .withSaturation(math.min(
            base.saturation * saturation, AppMotion.startupAuroraSaturation))
        .toColor();
    return [
      for (var i = 0; i < AppMotion.startupAuroraHues.length; i++)
        shade(AppMotion.startupAuroraHues[i],
            AppMotion.startupAuroraLightness[i], 1.8),
    ];
  }

  /// L'aurore en attendant la dominante du film : des gris profonds, jamais
  /// clairs (éclaircie, une dominante neutre donnait des taches presque
  /// blanches). Le fond change quand même au clap.
  static List<Color> get neutral => [
        for (final lightness in AppMotion.startupAuroraNeutralLightness)
          HSLColor.fromColor(AppColors.heroFallback)
              .withSaturation(0)
              .withLightness(lightness)
              .toColor(),
      ];

  /// Passage d'un jeu de couleurs à l'autre, tache par tache.
  static List<Color> blend(List<Color> from, List<Color> to, double t) => [
        for (var i = 0; i < to.length; i++) Color.lerp(from[i], to[i], t)!,
      ];

  /// Peint l'aurore sur [rect] : le fond, puis chaque tache, avec
  /// [intensity] de 0 (fond seul) à 1. [blendMode] permet de la poser dans
  /// un calque sans en changer la transparence (srcATop).
  ///
  /// Les taches sont floues par nature : elles sont peintes dans une petite
  /// image ([_resolution] pixels de long), agrandie à l'écran. Peintes en
  /// pleine taille, ces dégradés plein écran suffisaient à faire ramer
  /// certaines cartes graphiques (Windows : 50 à 110 ms par image).
  static void paint(Canvas canvas, Rect rect,
      {required List<Color> colors,
      required double intensity,
      BlendMode blendMode = BlendMode.srcOver}) {
    if (rect.isEmpty) return;
    final scale = math.min(1.0, _resolution / rect.longestSide);
    final width = math.max(1, (rect.width * scale).ceil());
    final height = math.max(1, (rect.height * scale).ceil());
    final recorder = ui.PictureRecorder();
    _paintFull(Canvas(recorder),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        colors: colors, intensity: intensity);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        rect,
        Paint()
          ..blendMode = blendMode
          ..filterQuality = FilterQuality.medium);
    image.dispose();
  }

  /// Côté le plus long de l'image de l'aurore.
  static const _resolution = 256.0;

  @visibleForTesting
  static void debugPaintFull(Canvas canvas, Rect rect,
          {required List<Color> colors, required double intensity}) =>
      _paintFull(canvas, rect, colors: colors, intensity: intensity);

  static void _paintFull(Canvas canvas, Rect rect,
      {required List<Color> colors,
      required double intensity,
      BlendMode blendMode = BlendMode.srcOver}) {
    canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.background
          ..blendMode = blendMode);
    if (intensity <= 0) return;
    final t = time.value * AppMotion.startupAuroraSpeed;
    final size = rect.longestSide;
    for (var i = 0; i < colors.length; i++) {
      // Chaque tache a son ancrage, réparti dans l'écran, et dérive
      // autour sur sa propre courbe de Lissajous : elles se croisent et se
      // mêlent au lieu de tourner ensemble autour du centre.
      final phase = i * 1.9;
      final anchor = AppMotion.startupAuroraAnchors[i];
      const drift = AppMotion.startupAuroraDrift;
      final centre = rect.center +
          Offset(
              (anchor.dx + drift.dx * math.sin(t * (0.9 + .31 * i) + phase)) *
                  rect.width,
              (anchor.dy +
                      drift.dy * math.cos(t * (0.7 + .27 * i) + phase * 1.3)) *
                  rect.height);
      final radius = size *
          (.42 + .08 * math.sin(t * (1.1 + .17 * i) + phase)) *
          ui.lerpDouble(.4, 1, intensity)!;
      canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..blendMode = blendMode
            // Chute douce (en S) : une chute linéaire marquait le bord de
            // chaque tache d'un anneau.
            ..shader = ui.Gradient.radial(
                centre,
                radius,
                [
                  for (final a in _falloff)
                    colors[i].withValues(alpha: a * intensity),
                ],
                _falloffStops));
    }
  }
}

/// Fait avancer l'horloge de l'aurore à chaque image tant qu'il est monté.
class StartupAuroraTicker extends StatefulWidget {
  const StartupAuroraTicker({super.key});

  @override
  State<StartupAuroraTicker> createState() => _StartupAuroraTickerState();
}

class _StartupAuroraTickerState extends State<StartupAuroraTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Démarré ici : déclaré paresseux, le minuteur n'était jamais créé et
    // l'aurore restait figée.
    _ticker = createTicker((_) => StartupAurora._tick())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
