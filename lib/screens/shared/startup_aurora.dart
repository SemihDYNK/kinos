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

  /// Secondes depuis le clap. Sans clap vu (intro passée), une onde depuis
  /// longtemps calmée : le liquide est entier.
  static double get wave =>
      clapAt == null ? AppMotion.startupLiquidCalm : time.value - clapAt!;

  /// Le fond, l'encre et le cœur chaud du liquide, tirés de la dominante.
  /// Un fond de la teinte opposée : le film orangé sur un fond sarcelle.
  static List<Color> liquidColorsFor(Color tint) {
    final base = HSLColor.fromColor(tint);
    Color shade((double, double, double) spec) => base
        .withHue((base.hue + spec.$1) % 360)
        .withSaturation(spec.$2)
        .withLightness(spec.$3)
        .toColor();
    return [
      shade(AppMotion.startupLiquidGround),
      shade(AppMotion.startupLiquidInk),
      shade(AppMotion.startupLiquidHot),
    ];
  }

  /// Le liquide en attendant la dominante : des gris.
  static List<Color> get liquidNeutral => [
        for (final lightness in AppMotion.startupLiquidNeutralLightness)
          HSLColor.fromAHSL(1, 0, 0, lightness).toColor(),
      ];

  /// Peint le fond liquide sur [rect] : [colors] (fond, encre, cœur),
  /// [wave] secondes après le clap. Comme l'aurore, dans une petite image
  /// agrandie à l'écran.
  static void paintLiquid(Canvas canvas, Rect rect,
      {required List<Color> colors,
      required double wave,
      double intensity = 1,
      BlendMode blendMode = BlendMode.srcOver}) {
    final program = _liquid;
    if (rect.isEmpty || program == null) return;
    final scale =
        math.min(1.0, AppMotion.startupLiquidResolution / rect.longestSide);
    final width = math.max(1, (rect.width * scale).ceil());
    final height = math.max(1, (rect.height * scale).ceil());
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
    color(AppColors.background);
    for (final c in colors) {
      color(c);
    }
    set(AppMotion.startupLiquidGrain);

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    shader.dispose();
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
