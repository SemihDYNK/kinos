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
/// place : le rideau couvre l'écran sauf le K, qui devient une fenêtre sur
/// l'accueil (son blanc se dissout, INOS s'efface). La caméra plonge
/// ensuite dans le creux du K : le trou grandit, et une ouverture ronde
/// partie du même point finit de découvrir l'écran. On voit à travers le K
/// le vrai bandeau, à sa vraie place : la continuité est exacte.
class StartupIntroOpening extends CustomPainter {
  const StartupIntroOpening(this.progress, {required this.markSize});
  final double progress;

  /// Côté de la marque à l'écran (le K seul).
  final double markSize;

  static const _extent = _StartupMarkPainter._extent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = size.center(Offset.zero);
    final notch = centre + StartupMark.notchOffset(markSize, intro: true);
    final unit = markSize / _extent;
    final dive = math.pow(AppMotion.startupIntroDiveZoom,
            AppMotion.startupIntroDive.transform(progress))
        .toDouble();
    // Repère du signe (mot posé) vers l'écran, puis la plongée autour du
    // creux du K.
    final toScreen = (Matrix4.identity()
          ..translateByDouble(notch.dx, notch.dy, 0, 1)
          ..scaleByDouble(dive, dive, 1, 1)
          ..translateByDouble(centre.dx - notch.dx, centre.dy - notch.dy, 0, 1)
          ..scaleByDouble(unit, unit, 1, 1)
          ..translateByDouble(
              -_extent / 2 - introWordShift, -_extent / 2, 0, 1))
        .storage;
    final k = _StartupMarkPainter._signature.transform(toScreen);

    final aperture = AppMotion.startupIntroAperture.transform(progress);
    var hole = k;
    if (aperture > 0) {
      final radius = [
            Offset.zero,
            Offset(size.width, 0),
            Offset(0, size.height),
            Offset(size.width, size.height),
          ].map((corner) => (corner - notch).distance).reduce(math.max) *
          aperture;
      hole = Path.combine(PathOperation.union, k,
          Path()..addOval(Rect.fromCircle(center: notch, radius: radius)));
    }
    canvas.drawPath(
        Path.combine(PathOperation.difference,
            Path()..addRect(Offset.zero & size), hole),
        Paint()..color = AppColors.background);

    final white = AppColors.textPrimary;
    final fill = 1 - AppMotion.startupIntroWindow.transform(progress);
    if (fill > 0) {
      canvas.drawPath(k, Paint()..color = white.withValues(alpha: fill));
    }
    final word = 1 - AppMotion.startupIntroWordOut.transform(progress);
    if (word > 0) {
      final paint = Paint()..color = white.withValues(alpha: word);
      for (final letter in wordmarkLetters) {
        canvas.drawPath(letter.transform(toScreen), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StartupIntroOpening oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.markSize != markSize;
}
