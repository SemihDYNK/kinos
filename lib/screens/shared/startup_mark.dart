import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

/// The signature's three original paths, assembled without changing the brand.
class StartupMark extends StatelessWidget {
  const StartupMark({required this.progress, this.intro = false, super.key});
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

/// Premier lancement de la session : depuis un gros plan, un trait de
/// lumière dessine le K en fantôme, les pièces arrivent des bords de
/// l'écran et du fond pendant que la caméra recule, et la branche du haut,
/// arrivée
/// ouverte, se referme comme un clap (cf. [AppMotion.startupIntroClap]).
class _StartupIntroPainter extends CustomPainter {
  const _StartupIntroPainter(this.progress);
  final double progress;

  static const _extent = _StartupMarkPainter._extent;
  static List<Path> get _parts => _StartupMarkPainter._parts;
  static List<ui.PathMetric> get _metrics => _StartupMarkPainter._metrics;
  static final _traceLength =
      _StartupMarkPainter._metrics.fold<double>(0, (sum, m) => sum + m.length);

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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide / _extent;
    final white = AppColors.textPrimary;
    if (progress >= 1) {
      canvas.scale(unit);
      for (final part in _parts) {
        canvas.drawPath(part, Paint()..color = white);
      }
      return;
    }
    final camera = AppMotion.startupIntroCamera.transform(progress);
    final zoom = ui.lerpDouble(AppMotion.startupIntroCloseup, 1, camera)!;
    final impact = impactScale(progress);
    // Échelle à l'écran d'une unité du signe : traits et tête de lumière
    // gardent leur taille en pixels pendant le recul de la caméra.
    final scale = unit * zoom * impact;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.transform((Matrix4.identity()
          ..setEntry(3, 2, AppMotion.startupMarkPerspective / _extent)
          ..rotateY(AppMotion.startupIntroTilt * (1 - camera)))
        .storage);
    canvas.translate(-_centre.dx, -_centre.dy);

    // Le contour fantôme : un seul trait qui parcourt les trois pièces à la
    // suite, avec une tête plus vive, puis s'efface au clap.
    final ghost = 1 - AppMotion.startupIntroGhostOut.transform(progress);
    final traced =
        AppMotion.startupIntroTrace.transform(progress) * _traceLength;
    if (ghost > 0 && traced > 0) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppBrand.startupGuideWidth / scale
        ..color = white.withValues(alpha: AppBrand.startupGuideOpacity * ghost);
      var start = 0.0;
      for (final metric in _metrics) {
        final length = (traced - start).clamp(0.0, metric.length);
        if (length > 0) {
          canvas.drawPath(metric.extractPath(0, length), stroke);
          if (length < metric.length) {
            final head = metric.getTangentForOffset(length)?.position;
            if (head != null) {
              canvas.drawCircle(head, AppMotion.startupIntroTraceHead,
                  Paint()..color = white.withValues(alpha: ghost));
            }
          }
        }
        start += metric.length;
      }
    }

    // Les pièces arrivent du fond vers leur place : petites et proches du
    // point de fuite au départ, puis à leur taille.
    for (var i = 0; i < _parts.length; i++) {
      final arrival = AppMotion.startupIntroArrivals[i].transform(progress);
      if (arrival <= 0) continue;
      final depth = ui.lerpDouble(AppMotion.startupIntroDepth, 1, arrival)!;
      // Depuis les bords de l'écran (même direction que l'assemblage court),
      // et du fond.
      final offset = AppMotion.startupMarkOffsets[i] *
          (_extent * AppMotion.startupIntroSpread * (1 - arrival));
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.translate(_centre.dx, _centre.dy);
      canvas.scale(depth);
      canvas.translate(-_centre.dx, -_centre.dy);
      if (i == 1) {
        canvas.translate(_hinge.dx, _hinge.dy);
        canvas.rotate(clapAngle(progress));
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
