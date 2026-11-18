import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/startup_aurora.dart';
import 'package:kinos/screens/shared/wordmark_letters.dart';
import 'package:kinos/theme/app_theme.dart';

/// The signature's three original paths, assembled without changing the brand.
class StartupMark extends StatelessWidget {
  const StartupMark(
      {required this.progress,
      this.intro = false,
      this.word = true,
      super.key});

  /// Creux du K (là où plonge la caméra à la sortie), par rapport au centre
  /// d'une marque de côté [size] ; dans le mot posé de l'intro, le K est
  /// décalé vers la gauche.
  static Offset notchOffset(double size,
          {bool intro = false, bool word = true}) =>
      (AppBrand.startupMarkNotch * _StartupMarkPainter._extent -
          Offset(intro && word ? introWordShift : 0, 0)) *
      (size / _StartupMarkPainter._extent);
  final double progress;

  /// Version longue du premier lancement de la session (allumage,
  /// assemblage en profondeur, clap) ; sinon, l'assemblage court.
  final bool intro;

  /// Intro avec le mot « KINOS » après le clap (premier lancement de la
  /// session) ; sans lui (lancements suivants), elle s'arrête au K
  /// assemblé, centré.
  final bool word;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Kinos',
        image: true,
        child: CustomPaint(
          size: const Size.square(AppBrand.startupMarkSize),
          painter: intro
              ? _StartupIntroPainter(progress, word: word)
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
  const _StartupIntroPainter(this.progress, {this.word = true});
  final double progress;
  final bool word;

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
    // Sans le mot, la même intro s'arrête à la fin de l'assemblage : son
    // avancement couvre seulement cette partie.
    final progress = this.word
        ? this.progress
        : this.progress * AppMotion.startupIntroAssemblyEnd;
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
      oldDelegate.progress != progress || oldDelegate.word != word;
}

/// Ouverture après l'intro longue, peinte par-dessus l'accueil déjà en
/// place : les deux branches du K sont un projecteur. L'espace entre elles
/// (la bouche du K) s'allume sur l'accueil, puis elles pivotent autour du
/// creux du K en s'écartant ; le faisceau, aux bords adoucis, s'élargit
/// jusqu'à couvrir l'écran. On voit dans le faisceau le vrai accueil, à sa
/// vraie place.
class StartupIntroBeam extends CustomPainter {
  StartupIntroBeam(this.progress,
      {required this.markSize, this.tint, this.word = true})
      : super(repaint: StartupAurora.time);
  final double progress;

  /// Le rideau part du mot posé (K décalé, INOS qui s'efface) ; sinon du K
  /// seul, centré.
  final bool word;

  /// Dominante du film : le rideau garde l'aurore née au clap (cf.
  /// [StartupAurora]) jusqu'à ce qu'il s'efface.
  final Color? tint;

  /// Côté de la marque à l'écran (le K seul).
  final double markSize;

  static const _extent = _StartupMarkPainter._extent;
  // Source du faisceau, reculée dans la hampe (cachée par son blanc) : la
  // bouche du K est une fente de 10 unités de haut au creux, et un
  // faisceau parti d'un point y laissait deux petits triangles noirs. D'ici,
  // il couvre toute la fente dès sa sortie.
  static const _source = Offset(62, 128);

  // Coin intérieur de la branche du haut, où la bouche du K s'évase : le
  // bord du faisceau passe par lui, et il tourne autour de la source avec
  // la branche (le volet). Celui du bas est son symétrique.
  static const _mouthCorner = Offset(168, 95);

  /// Demi-angle de départ du faisceau : celui de la bouche du K vue depuis
  /// la source.
  static final mouthAngle =
      math.atan2(_source.dy - _mouthCorner.dy, _mouthCorner.dx - _source.dx);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = size.center(Offset.zero);
    final unit = markSize / _extent;
    Offset toScreen(Offset p) =>
        centre +
        (p - const Offset(_extent / 2, _extent / 2)) * unit -
        Offset(word ? introWordShift * unit : 0, 0);
    final notch = toScreen(_source);

    final on = AppMotion.startupIntroBeamOn.transform(progress);
    final open = AppMotion.startupIntroBeamOpen.transform(progress);
    final half = ui.lerpDouble(mouthAngle, AppMotion.startupIntroBeamTo, open)!;

    // Le rideau, percé par le faisceau : la lumière part du creux du K et
    // s'allonge vers l'extérieur derrière un front adouci, pendant que son
    // intensité monte. Au tout premier instant, rien ne passe.
    //
    // Tout est dessiné directement, sans calque intermédiaire ni flou de
    // masque : recalculés à chaque image pendant que l'accueil décode ses
    // images, ils faisaient sauter des images. Les bords du faisceau sont
    // adoucis par un dégradé, comme ceux de l'iris.
    final length = AppMotion.startupIntroBeamReach.transform(progress) *
        size.longestSide *
        1.5;
    final background = Paint()..color = AppColors.background;
    // L'aurore née au clap, au même instant de son mouvement.
    // Sans dominante (pas encore calculée), l'aurore neutre en gris profonds.
    final aurora =
        tint == null ? StartupAurora.neutral : StartupAurora.colorsFor(tint!);
    const glowing = 1.0;
    if (on <= 0 || length <= 0) {
      StartupAurora.paint(canvas, Offset.zero & size,
          colors: aurora, intensity: glowing);
      _paintMark(canvas, toScreen, unit, half, progress);
      return;
    }

    // Un éventail depuis le creux, de la longueur de la lumière.
    Path fan(double halfAngle) {
      final path = Path()..moveTo(notch.dx, notch.dy);
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final angle = -halfAngle + 2 * halfAngle * i / steps;
        path.lineTo(notch.dx + length * math.cos(angle),
            notch.dy + length * math.sin(angle));
      }
      return path..close();
    }

    // Bords adoucis comme ceux de l'iris : de chaque côté, une bande de
    // largeur constante où le rideau passe en dégradé de transparent à
    // opaque, perpendiculairement au bord. Les bandes restent hors du
    // faisceau (près de la source, quand il est très ouvert, elles y
    // débordaient en tache sombre).
    final beam = fan(half);
    const feather = AppBrand.startupApertureFeather;
    var lit = beam;
    final edges = <(Path, Paint)>[];
    for (final side in const [-1.0, 1.0]) {
      final angle = side * half;
      final along = Offset(math.cos(angle), math.sin(angle));
      final out = Offset(-math.sin(angle), math.cos(angle)) * side;
      var band = Path.combine(
          PathOperation.difference,
          Path()
            ..moveTo(notch.dx, notch.dy)
            ..lineTo(notch.dx + along.dx * length, notch.dy + along.dy * length)
            ..lineTo(notch.dx + along.dx * length + out.dx * feather,
                notch.dy + along.dy * length + out.dy * feather)
            ..lineTo(notch.dx + out.dx * feather, notch.dy + out.dy * feather)
            ..close(),
          beam);
      // Chaque bande reste de son côté de l'axe du faisceau : très ouvert,
      // leurs dégradés se superposaient près de la source en losange sombre.
      final reach = size.longestSide * 2;
      band = Path.combine(
          PathOperation.intersect,
          band,
          Path()
            ..addRect(side < 0
                ? Rect.fromLTRB(notch.dx - reach, notch.dy - reach,
                    notch.dx + reach, notch.dy)
                : Rect.fromLTRB(notch.dx - reach, notch.dy, notch.dx + reach,
                    notch.dy + reach)));
      edges.add((
        band,
        Paint()
          ..shader = ui.Gradient.linear(notch, notch + out * feather, [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ])
      ));
      lit = Path.combine(PathOperation.union, lit, band);
    }

    // La lumière du projecteur : une lueur additive, plus forte près du K,
    // qui s'éteint pendant l'élargissement pour rendre à l'accueil ses
    // vraies couleurs. Sans elle, le faisceau ne montre que la partie
    // sombre du bandeau et ne se lit pas comme de la lumière. Posée avant
    // les bords adoucis, elle s'estompe avec l'image à travers eux, au lieu
    // de s'arrêter net au bord du faisceau.
    final glow = 1 - AppMotion.startupIntroBeamGlowOut.transform(progress);
    // Nulle à la source (dans la hampe), elle n'atteint son maximum qu'à la
    // sortie de la bouche du K : sinon elle débordait en tache blanche
    // dans la fente du creux, entre la hampe et les volets.
    final mouth =
        ((_mouthCorner - _source).distance * unit / length).clamp(0.0, .5);
    if (glow > 0) {
      canvas.drawPath(
          lit,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(
              notch,
              length,
              [
                Colors.white.withValues(alpha: 0),
                Colors.white
                    .withValues(alpha: AppMotion.startupIntroBeamGlow * glow),
                Colors.white.withValues(
                    alpha: AppMotion.startupIntroBeamGlow * glow * .35),
                Colors.white.withValues(alpha: 0),
              ],
              [0, mouth, math.max(mouth, .55), 1],
            ));
    }
    // Le rideau (bords adoucis compris) est dessiné dans un calque, puis
    // recoloré par l'aurore du clap là où il couvre : sa transparence
    // dans les bords est conservée.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final (band, paint) in edges) {
      canvas.drawPath(band, paint);
    }
    canvas.drawPath(
        Path.combine(
            PathOperation.difference, Path()..addRect(Offset.zero & size), lit),
        background);
    // Dans la lumière : le rideau s'efface à l'allumage.
    if (on < 1) {
      canvas.drawPath(
          lit, Paint()..color = AppColors.background.withValues(alpha: 1 - on));
    }
    // Derrière le front de la lumière, faisceau et bords compris, le rideau
    // reste entier.
    canvas.drawPath(
        lit,
        Paint()
          ..shader = ui.Gradient.radial(
            notch,
            length,
            [
              AppColors.background.withValues(alpha: 0),
              AppColors.background.withValues(alpha: 0),
              AppColors.background,
            ],
            const [0, 1 - AppMotion.startupIntroBeamFront, 1],
          ));

    StartupAurora.paint(canvas, Offset.zero & size,
        colors: aurora, intensity: glowing, blendMode: BlendMode.srcATop);
    canvas.restore();

    _paintMark(canvas, toScreen, unit, half, progress);
  }

  /// Le K (la hampe reste, les branches pivotent avec les bords du
  /// faisceau, puis tout s'efface) et INOS, qui s'efface à l'allumage.
  void _paintMark(Canvas canvas, Offset Function(Offset) toScreen, double unit,
      double half, double progress) {
    // Le K : la hampe reste, les branches sont les volets du projecteur.
    // Elles tournent autour de la source du faisceau, si bien que leur coin
    // intérieur reste sur le bord de la lumière : le faisceau ne s'élargit
    // que parce qu'elles s'écartent. Tout s'efface à la fin.
    final mark = 1 - AppMotion.startupIntroMarkOut.transform(progress);
    if (mark > 0) {
      final white = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: mark);
      final turn = half - mouthAngle;
      canvas.save();
      canvas.translate(toScreen(Offset.zero).dx, toScreen(Offset.zero).dy);
      canvas.scale(unit);
      final parts = _StartupMarkPainter._parts;
      canvas.drawPath(parts[0], white);
      for (final (index, sign) in [(1, -1.0), (2, 1.0)]) {
        canvas.save();
        canvas.translate(_source.dx, _source.dy);
        canvas.rotate(sign * turn);
        canvas.translate(-_source.dx, -_source.dy);
        canvas.drawPath(parts[index], white);
        canvas.restore();
      }
      canvas.restore();
    }

    final letters =
        word ? 1 - AppMotion.startupIntroWordOut.transform(progress) : 0.0;
    if (letters > 0) {
      canvas.save();
      canvas.translate(toScreen(Offset.zero).dx, toScreen(Offset.zero).dy);
      canvas.scale(unit);
      final paint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: letters);
      for (final letter in wordmarkLetters) {
        canvas.drawPath(letter, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StartupIntroBeam oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.markSize != markSize ||
      oldDelegate.tint != tint ||
      oldDelegate.word != word;
}
