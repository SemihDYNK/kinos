import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

/// The signature's three original paths, assembled without changing the brand.
class StartupMark extends StatelessWidget {
  const StartupMark({required this.progress, super.key});
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Kinos',
        image: true,
        child: CustomPaint(
          size: const Size.square(AppBrand.startupMarkSize),
          painter: _StartupMarkPainter(progress),
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
