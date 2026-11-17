import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/wordmark_letters.dart';
import 'package:kinos/theme/app_theme.dart';

/// The signature's three original paths, assembled without changing the brand.
class StartupMark extends StatelessWidget {
  const StartupMark({required this.progress, this.intro = false, super.key});

  /// Creux du K (là où plonge la caméra à la sortie), par rapport au centre
  /// d'une marque de côté [size] ; dans le mot posé de l'intro, le K est
  /// décalé vers la gauche.
  static Offset notchOffset(double size, {bool intro = false}) =>
      (AppBrand.startupMarkNotch * _StartupMarkPainter._extent -
          Offset(intro ? introWordShift : 0, 0)) *
      (size / _StartupMarkPainter._extent);
  final double progress;

  /// Version longue du premier lancement de la session (allumage,
  /// assemblage en profondeur, clap) ; sinon, l'assemblage court.
  final bool intro;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Kinos',
        image: true,
        child: CustomPaint(
          size: const Size.square(AppBrand.startupMarkSize),
          painter: intro
              ? _StartupIntroPainter(progress)
              : _StartupMarkPainter(progress),
        ),
      );
}

class _StartupMarkPainter extends CustomPainter {
  const _StartupMarkPainter(this.progress);
  final double progress;

  // Geometry is in the existing kinos_signature_final.svg viewBox, not pixels.
  static const _extent = 256.0;
  // Bord gauche de la hampe du K.
  static const _kLeft = 20.0;
  static final _parts = <Path>[
    Path()..addRect(const Rect.fromLTRB(20, 26, 80, 230)),
    Path()
      ..moveTo(80, 123)
      ..cubicTo(118, 80, 124, 15, 198, 15)
      ..lineTo(239, 15)
      ..lineTo(168, 95)
      ..cubicTo(145, 123, 113, 123, 80, 123)
      ..close(),
    Path()
      ..moveTo(80, 133)
      ..cubicTo(118, 176, 124, 241, 198, 241)
      ..lineTo(239, 241)
      ..lineTo(168, 161)
      ..cubicTo(145, 133, 113, 133, 80, 133)
      ..close(),
  ];
  static final _metrics = _parts.map((p) => p.computeMetrics().first).toList();
  static final _signature = Path()
    ..addPath(_parts[0], Offset.zero)
    ..addPath(_parts[1], Offset.zero)
    ..addPath(_parts[2], Offset.zero);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide / _extent;
    if (progress >= 1) {
      canvas.scale(unit);
      canvas.drawPath(_signature, Paint()..color = AppColors.textPrimary);
      return;
    }
    final camera = AppMotion.startupMarkCamera.transform(progress);
    final zoom = ui.lerpDouble(AppMotion.startupMarkCloseup, 1, camera)!;
    final fill = AppMotion.startupMarkFill.transform(progress);
    final trace = AppMotion.startupMarkTrace.transform(progress);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(unit * zoom);
    // Un vrai pivot en profondeur : sans le terme de perspective, la
    // rotation autour de l'axe vertical ne fait qu'écraser le K en largeur.
    canvas.transform((Matrix4.identity()
          ..setEntry(3, 2, AppMotion.startupMarkPerspective / _extent)
          ..rotateY(AppMotion.startupMarkTilt * (1 - camera))
          ..rotateZ(AppMotion.startupMarkAngle * (1 - camera)))
        .storage);
    canvas.translate(
        -ui.lerpDouble(176, 128, camera)!, -ui.lerpDouble(80, 128, camera)!);
    // Le blanc gagne le K de la hampe vers la pointe des branches, dans le
    // sens où les pièces se rejoignent, derrière un bord adouci.
    const edge = AppMotion.startupMarkFillEdge * _extent;
    final front = ui.lerpDouble(-edge, _extent, fill)!;
    for (var i = 0; i < _parts.length; i++) {
      final assembly = AppMotion.startupMarkAssembly[i].transform(progress);
      final offset =
          AppMotion.startupMarkOffsets[i] * (_extent * (1 - assembly));
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      final metric = _metrics[i];
      canvas.drawPath(
          metric.extractPath(0, metric.length * trace),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppBrand.startupGuideWidth / (unit * zoom)
            ..color = AppColors.textPrimary
                .withValues(alpha: AppBrand.startupGuideOpacity * (1 - fill)));
      if (fill > 0) {
        // Le dégradé est posé dans le repère du signe assemblé, pas dans
        // celui de la pièce qui glisse encore.
        canvas.drawPath(
            _parts[i],
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(front - offset.dx, 0),
                Offset(front + edge - offset.dx, 0),
                [
                  AppColors.textPrimary,
                  AppColors.textPrimary.withValues(alpha: 0),
                ],
              ));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StartupMarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Premier lancement de la session : depuis un gros plan, le contour du
/// K se dessine en fantôme, les pièces arrivent des bords de
/// l'écran et du fond pendant que la caméra recule, et la branche du haut,
/// arrivée
/// ouverte, se referme comme un clap (cf. [AppMotion.startupIntroClap]).
/// Décalage du K vers la gauche, en unités du signe, pour que « KINOS »
/// soit centré là où se tenait le K seul.
final double introWordShift = (_StartupMarkPainter._kLeft + wordmarkRight) / 2 -
    _StartupMarkPainter._extent / 2;

class _StartupIntroPainter extends CustomPainter {
  const _StartupIntroPainter(this.progress);
  final double progress;

  static const _extent = _StartupMarkPainter._extent;
  static List<Path> get _parts => _StartupMarkPainter._parts;
  static List<ui.PathMetric> get _metrics => _StartupMarkPainter._metrics;

  // Charnière de la branche du haut : là où elle rejoint la hampe.
  static const _hinge = Offset(80, 123);
  static const _centre = Offset(_extent / 2, _extent / 2);

  /// Angle de la branche du haut : ouverte, élan, puis fermeture.
  static double clapAngle(double progress) {
    final windup = AppMotion.startupIntroClapWindup.transform(progress);
    final close = AppMotion.startupIntroClapClose.transform(progress);
    final lifted = AppMotion.startupIntroClapOpen +
        AppMotion.startupIntroClapLift * windup;
    return lifted * (1 - close);
  }

  /// Échelle de la marque : 1, comprimée au choc, puis reposée sans rebond.
  static double impactScale(double progress) {
    final hit = AppMotion.startupIntroImpactIn.transform(progress) -
        AppMotion.startupIntroImpactOut.transform(progress);
    return 1 - AppMotion.startupIntroImpact * hit;
  }

  /// Le mot posé : K et INOS, centrés ensemble.
  void _paintWord(Canvas canvas, double word, Paint paint) {
    final slide = AppMotion.startupIntroWordSlide.transform(word);
    canvas.translate(-introWordShift * slide, 0);
    for (final part in _parts) {
      canvas.drawPath(part, paint);
    }
    for (var i = 0; i < wordmarkLetters.length; i++) {
      final letter = AppMotion.startupIntroLetters[i].transform(word);
      if (letter <= 0) continue;
      // Les lettres arrivent écartées et se resserrent jusqu'au mot.
      canvas.save();
      canvas.translate(
          AppMotion.startupIntroTracking * (i + 1) * (1 - letter), 0);
      canvas.drawPath(wordmarkLetters[i],
          Paint()..color = paint.color.withValues(alpha: letter));
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide / _extent;
    final white = AppColors.textPrimary;
    final word = AppMotion.startupIntroWord.transform(progress);
    if (word > 0) {
      // Assemblage fini : le K est à sa taille, sans caméra ni choc.
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(unit);
      canvas.translate(-_centre.dx, -_centre.dy);
      _paintWord(canvas, word, Paint()..color = white);
      return;
    }
    // Avancement de l'assemblage et du clap, avant le mot.
    final a = (progress / AppMotion.startupIntroAssemblyEnd).clamp(0.0, 1.0);
    final camera = AppMotion.startupIntroCamera.transform(a);
    final zoom = ui.lerpDouble(AppMotion.startupIntroCloseup, 1, camera)!;
    final impact = impactScale(a);
    // Échelle à l'écran d'une unité du signe : les traits gardent leur
    // épaisseur en pixels pendant le recul de la caméra.
    final scale = unit * zoom * impact;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.transform((Matrix4.identity()
          ..setEntry(3, 2, AppMotion.startupMarkPerspective / _extent)
          ..rotateY(AppMotion.startupIntroTilt * (1 - camera)))
        .storage);
    canvas.translate(-_centre.dx, -_centre.dy);

    // Le contour fantôme : les trois contours se dessinent ensemble, d'un
    // mouvement régulier, apparaissent en fondu, puis s'effacent au clap.
    final ghost = 1 - AppMotion.startupIntroGhostOut.transform(a);
    final trace = AppMotion.startupIntroTrace.transform(a);
    final appear = AppMotion.startupIntroTraceFade.transform(a);
    if (ghost > 0 && trace > 0) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBrand.startupGuideWidth / scale
        ..color = white.withValues(
            alpha: AppBrand.startupGuideOpacity * ghost * appear);
      for (final metric in _metrics) {
        canvas.drawPath(metric.extractPath(0, metric.length * trace), stroke);
      }
    }

    // Les pièces arrivent des bords et du fond vers leur place.
    for (var i = 0; i < _parts.length; i++) {
      final arrival = AppMotion.startupIntroArrivals[i].transform(a);
      if (arrival <= 0) continue;
      final depth = ui.lerpDouble(AppMotion.startupIntroDepth, 1, arrival)!;
      final offset = AppMotion.startupMarkOffsets[i] *
          (_extent * AppMotion.startupIntroSpread * (1 - arrival));
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.translate(_centre.dx, _centre.dy);
      canvas.scale(depth);
      canvas.translate(-_centre.dx, -_centre.dy);
      if (i == 1) {
        canvas.translate(_hinge.dx, _hinge.dy);
        canvas.rotate(clapAngle(a));
        canvas.translate(-_hinge.dx, -_hinge.dy);
      }
      canvas.drawPath(
          _parts[i], Paint()..color = white.withValues(alpha: arrival));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StartupIntroPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Ouverture après l'intro longue, peinte par-dessus l'accueil déjà en
/// place : les deux branches du K sont un projecteur. L'espace entre elles
/// (la bouche du K) s'allume sur l'accueil, puis elles pivotent autour du
/// creux du K en s'écartant ; le faisceau, aux bords adoucis, s'élargit
/// jusqu'à couvrir l'écran. On voit dans le faisceau le vrai accueil, à sa
/// vraie place.
class StartupIntroBeam extends CustomPainter {
  const StartupIntroBeam(this.progress, {required this.markSize});
  final double progress;

  /// Côté de la marque à l'écran (le K seul).
  final double markSize;

  static const _extent = _StartupMarkPainter._extent;
  // Creux du K, d'où part le faisceau (repère du signe).
  static const _hinge = Offset(80, 128);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = size.center(Offset.zero);
    final unit = markSize / _extent;
    Offset toScreen(Offset p) =>
        centre +
        (p - const Offset(_extent / 2, _extent / 2)) * unit -
        Offset(introWordShift * unit, 0);
    final notch = toScreen(_hinge);

    final on = AppMotion.startupIntroBeamOn.transform(progress);
    final open = AppMotion.startupIntroBeamOpen.transform(progress);
    final half = ui.lerpDouble(
        AppMotion.startupIntroBeamFrom, AppMotion.startupIntroBeamTo, open)!;

    // Le rideau, percé par le faisceau : la lumière part du creux du K et
    // s'allonge vers l'extérieur derrière un front adouci, pendant que son
    // intensité monte. Au tout premier instant, rien ne passe.
    const feather = AppMotion.startupIntroBeamFeather;
    final length = AppMotion.startupIntroBeamReach.transform(progress) *
        size.longestSide *
        1.5;
    if (on <= 0 || length <= 0) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = AppColors.background);
      _paintMark(canvas, toScreen, unit, half, progress);
      return;
    }

    // Le faisceau : un éventail depuis le creux, de la longueur de la
    // lumière (rien au-delà : le flou coûte selon la taille du tracé).
    final beam = Path()..moveTo(notch.dx, notch.dy);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final angle = -half + 2 * half * i / steps;
      beam.lineTo(notch.dx + length * math.cos(angle),
          notch.dy + length * math.sin(angle));
    }
    beam.close();

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    canvas.drawPath(
        beam,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, feather / 2)
          ..shader = ui.Gradient.radial(
            notch,
            length,
            [
              Colors.white.withValues(alpha: on),
              Colors.white.withValues(alpha: on),
              Colors.white.withValues(alpha: 0),
            ],
            const [0, 1 - AppMotion.startupIntroBeamFront, 1],
          ));
    canvas.restore();

    // La lumière du projecteur : une lueur additive dans le faisceau, plus
    // forte près du K, qui s'éteint pendant l'élargissement pour rendre à
    // l'accueil ses vraies couleurs. Sans elle, le faisceau ne montre que
    // la partie sombre du bandeau et ne se lit pas comme de la lumière.
    final glow =
        on * (1 - AppMotion.startupIntroBeamGlowOut.transform(progress));
    if (glow > 0) {
      // Sans flou : le dégradé est déjà doux, et un second flou plein écran
      // coûtait des images pendant que l'accueil décode les siennes.
      canvas.drawPath(
          beam,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(
              notch,
              length,
              [
                Colors.white
                    .withValues(alpha: AppMotion.startupIntroBeamGlow * glow),
                Colors.white.withValues(
                    alpha: AppMotion.startupIntroBeamGlow * glow * .35),
                Colors.white.withValues(alpha: 0),
              ],
              const [0, .55, 1],
            ));
    }

    _paintMark(canvas, toScreen, unit, half, progress);
  }

  /// Le K (la hampe reste, les branches pivotent avec les bords du
  /// faisceau, puis tout s'efface) et INOS, qui s'efface à l'allumage.
  void _paintMark(Canvas canvas, Offset Function(Offset) toScreen, double unit,
      double half, double progress) {
    // Le K : la hampe reste, les branches pivotent avec les bords du
    // faisceau, puis tout s'efface.
    final mark = 1 - AppMotion.startupIntroMarkOut.transform(progress);
    if (mark > 0) {
      final white = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: mark);
      final turn = half - AppMotion.startupIntroBeamFrom;
      canvas.save();
      canvas.translate(toScreen(Offset.zero).dx, toScreen(Offset.zero).dy);
      canvas.scale(unit);
      final parts = _StartupMarkPainter._parts;
      canvas.drawPath(parts[0], white);
      for (final (index, sign) in [(1, -1.0), (2, 1.0)]) {
        canvas.save();
        canvas.translate(_hinge.dx, _hinge.dy);
        canvas.rotate(sign * turn);
        canvas.translate(-_hinge.dx, -_hinge.dy);
        canvas.drawPath(parts[index], white);
        canvas.restore();
      }
      canvas.restore();
    }

    final word = 1 - AppMotion.startupIntroWordOut.transform(progress);
    if (word > 0) {
      canvas.save();
      canvas.translate(toScreen(Offset.zero).dx, toScreen(Offset.zero).dy);
      canvas.scale(unit);
      final paint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: word);
      for (final letter in wordmarkLetters) {
        canvas.drawPath(letter, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StartupIntroBeam oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.markSize != markSize;
}
