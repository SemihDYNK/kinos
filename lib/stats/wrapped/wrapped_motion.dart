import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';

/// L'horloge d'une diapo : ses secondes écoulées, et sa durée. Tout le
/// mouvement d'une diapo s'écrit en secondes depuis son début, comme un
/// générique minuté.
class WrappedClock extends InheritedNotifier<Animation<double>> {
  const WrappedClock(
      {required this.duration,
      required this.motion,
      required Animation<double> progress,
      required super.child,
      super.key})
      : super(notifier: progress);

  /// Durée de la diapo, en secondes.
  final double duration;

  /// Faux quand le système demande moins de mouvement : tout est posé.
  final bool motion;

  static WrappedClock _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WrappedClock>()!;

  /// Secondes écoulées depuis le début de la diapo.
  static double seconds(BuildContext context) {
    final clock = _of(context);
    return (clock.notifier?.value ?? 1) * clock.duration;
  }

  static bool motionOf(BuildContext context) => _of(context).motion;

  /// Avancement de 0 à 1 d'un mouvement qui commence à [at] et dure
  /// [length] secondes. 1 sans mouvement.
  static double at(BuildContext context, double at,
      {double length = AppWrapped.reveal, Curve curve = AppMotion.easeOut}) {
    final clock = _of(context);
    if (!clock.motion) return 1;
    final t = ((clock.notifier?.value ?? 1) * clock.duration - at) / length;
    return curve.transform(t.clamp(0.0, 1.0));
  }
}

/// Les tailles de texte d'une diapo, proportionnelles à sa hauteur.
class WrappedType {
  WrappedType(Size size)
      : big = AppTypography.heroEditorial.copyWith(
            fontSize: size.height * AppWrapped.bigFraction,
            height: 1,
            color: AppColors.textPrimary),
        mid = AppTypography.display.copyWith(
            fontSize: size.height * AppWrapped.midFraction,
            height: 1.15,
            color: AppColors.textPrimary),
        small = AppTypography.body.copyWith(
            fontSize: math.max(
                AppWrapped.minSmall, size.height * AppWrapped.smallFraction),
            height: 1.5,
            color: AppColors.textPrimary.withValues(alpha: .75)),
        cap = AppTypography.overline.copyWith(
            fontSize: math.max(
                AppWrapped.minCap, size.height * AppWrapped.capFraction),
            color: AppColors.textPrimary.withValues(alpha: .75));

  final TextStyle big;
  final TextStyle mid;
  final TextStyle small;
  final TextStyle cap;
}

/// Un texte qui entre comme au générique : fondu, légère montée, et ses
/// lettres qui se resserrent. Les petites capitales gardent leur grand
/// espacement.
class WrappedText extends StatelessWidget {
  const WrappedText(this.text,
      {required this.style,
      required this.at,
      this.caps = false,
      this.textAlign,
      this.maxLines,
      super.key});
  final String text;
  final TextStyle style;
  final double at;
  final bool caps;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final p = WrappedClock.at(context, at);
    final tracking = WrappedClock.at(context, at,
        length: AppWrapped.tracking, curve: Curves.easeOutCubic);
    final size = style.fontSize ?? 14;
    final spacing = caps
        ? size * AppWrapped.capTracking
        : (style.letterSpacing ?? 0) +
            size * AppWrapped.trackingFrom * (1 - tracking);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, (1 - p) * size * .2),
        child: Text(caps ? text.toUpperCase() : text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: style.copyWith(letterSpacing: spacing)),
      ),
    );
  }
}

/// L'image avance lentement sur toute la diapo, comme une caméra.
class KenBurns extends StatelessWidget {
  const KenBurns(
      {required this.child,
      this.from = 0,
      this.length,
      this.amount = AppWrapped.kenBurns,
      super.key});
  final Widget child;

  /// Début et durée du mouvement (secondes) ; toute la diapo par défaut.
  final double from;
  final double? length;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final clock = context.dependOnInheritedWidgetOfExactType<WrappedClock>()!;
    final p = WrappedClock.at(context, from,
        length: length ?? clock.duration, curve: Curves.linear);
    return ClipRect(
        child: Transform.scale(scale: 1 + amount * p, child: child));
  }
}

/// Une image de film en plein cadre.
class WrappedImage extends StatelessWidget {
  const WrappedImage(this.image, {this.alignment, super.key});
  final ImageData? image;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) => image == null
      ? const ColoredBox(color: AppColors.heroFallback)
      : KinosImage(
          key: ValueKey(image!.key),
          image: image,
          alignment: alignment ?? AppHeroLayout.imageAlignment,
          disableBlur: true);
}

/// Les images de plusieurs films qui se relaient en fondu, chacune avec son
/// avancée lente.
class CyclingBackdrops extends StatelessWidget {
  const CyclingBackdrops(this.images, {super.key});
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const ColoredBox(color: AppColors.heroFallback);
    }
    final t = WrappedClock.seconds(context);
    final index = WrappedClock.motionOf(context)
        ? (t / AppWrapped.backdropCycle).floor() % images.length
        : 0;
    final start =
        (t / AppWrapped.backdropCycle).floor() * AppWrapped.backdropCycle;
    return AnimatedSwitcher(
      duration: WrappedClock.motionOf(context)
          ? const Duration(milliseconds: 1600)
          : Duration.zero,
      child: KenBurns(
          key: ValueKey(index),
          from: start,
          length: AppWrapped.backdropCycle * 1.5,
          child: WrappedImage(images[index])),
    );
  }
}

/// Le voile de lecture : uniforme, puis dégradé depuis le côté du texte
/// (gauche) et le bas. [opacity] permet de le faire entrer.
class WrappedScrim extends StatelessWidget {
  const WrappedScrim(
      {this.opacity = 1, this.veil = AppWrapped.veil, super.key});
  final double opacity;
  final double veil;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: AppColors.scrim.withValues(alpha: veil * .6)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0, .45, AppWrapped.scrimReach],
                  colors: [
                    AppColors.scrim.withValues(alpha: AppWrapped.scrim),
                    AppColors.scrim.withValues(alpha: AppWrapped.scrim * .7),
                    AppColors.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0, .45],
                  colors: [
                    AppColors.scrim.withValues(alpha: veil),
                    AppColors.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Le bloc de texte d'une diapo, à gauche et centré verticalement.
class WrappedTextBlock extends StatelessWidget {
  const WrappedTextBlock(
      {required this.children,
      this.alignment = Alignment.centerLeft,
      this.crossAxisAlignment = CrossAxisAlignment.start,
      this.widthFraction = .62,
      super.key});
  final List<Widget> children;
  final Alignment alignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double widthFraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => Padding(
            padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * AppWrapped.inset),
            child: Align(
              alignment: alignment,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * widthFraction),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: children),
              ),
            ),
          ));
}

/// Le grain de pellicule : une texture de bruit générée une fois, répétée
/// sur toute la diapo et décalée à chaque image (24 fois par seconde),
/// fondue en incrustation. [opacity] règle sa présence.
class WrappedGrain extends StatefulWidget {
  const WrappedGrain({required this.opacity, super.key});
  final double opacity;

  @override
  State<WrappedGrain> createState() => _WrappedGrainState();
}

class _WrappedGrainState extends State<WrappedGrain> {
  static const _size = 128;
  static ui.Image? _noise;
  static Future<ui.Image>? _loading;

  static Future<ui.Image> _load() {
    final random = math.Random(7);
    final pixels = Uint8List(_size * _size * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      final v = random.nextInt(256);
      pixels[i] = v;
      pixels[i + 1] = v;
      pixels[i + 2] = v;
      pixels[i + 3] = 255;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, _size, _size, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  @override
  void initState() {
    super.initState();
    if (_noise == null) {
      (_loading ??= _load()).then((image) {
        _noise = image;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final noise = _noise;
    if (noise == null || widget.opacity <= 0) return const SizedBox.shrink();
    final frame = WrappedClock.motionOf(context)
        ? (WrappedClock.seconds(context) * 24).floor()
        : 0;
    return IgnorePointer(
      child: CustomPaint(
          size: Size.infinite,
          painter: _GrainPainter(noise, widget.opacity, frame)),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.noise, this.opacity, this.frame);
  final ui.Image noise;
  final double opacity;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(frame);
    final shift = Matrix4.identity()
      ..translateByDouble(
          random.nextDouble() * 128, random.nextDouble() * 128, 0, 1)
      ..scaleByDouble(1.6, 1.6, 1, 1);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ImageShader(
              noise, TileMode.repeated, TileMode.repeated, shift.storage)
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..blendMode = BlendMode.overlay);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.frame != frame || old.opacity != opacity || old.noise != noise;
}

/// Un afficheur à palettes, comme les horloges et les tableaux de gare :
/// chaque caractère est une palette, et seule celle dont le caractère
/// change bascule — la moitié haute de l'ancien se rabat, puis la moitié
/// basse du nouveau se pose. Jamais deux textes mêlés.
class SplitFlapText extends StatelessWidget {
  const SplitFlapText(this.text, {required this.style, super.key});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final digits = style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()], height: 1.1);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, char) in text.characters.indexed) ...[
        if (i > 0) SizedBox(width: (style.fontSize ?? 14) * .08),
        _Flap(key: ValueKey(i), char: char, style: digits),
      ],
    ]);
  }
}

class _Flap extends StatefulWidget {
  const _Flap({required this.char, required this.style, super.key});
  final String char;
  final TextStyle style;

  @override
  State<_Flap> createState() => _FlapState();
}

class _FlapState extends State<_Flap> with SingleTickerProviderStateMixin {
  late final _flip =
      AnimationController(vsync: this, duration: AppWrapped.flapDuration)
        ..value = 1;
  late String _from = widget.char;

  @override
  void didUpdateWidget(_Flap old) {
    super.didUpdateWidget(old);
    if (old.char != widget.char) {
      _from = old.char;
      if (AppMotion.enabled(context)) {
        _flip.forward(from: 0);
      } else {
        _flip.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Widget _half(String char, {required bool top}) => ClipRect(
        child: Align(
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          heightFactor: .5,
          child: _tile(char),
        ),
      );

  Widget _tile(String char) {
    final size = widget.style.fontSize ?? 14;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scrim.withValues(alpha: AppWrapped.flapTile),
        borderRadius: BorderRadius.circular(size * .08),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * .12),
        child: Text(char, style: widget.style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_flip.value);
          final to = widget.char;
          final firstHalf = t < .5;
          final angle =
              firstHalf ? t * 2 * math.pi / 2 : (1 - t) * 2 * math.pi / 2;
          return Stack(children: [
            // Le fond : le haut du nouveau, le bas de l'ancien.
            Column(mainAxisSize: MainAxisSize.min, children: [
              _half(to, top: true),
              _half(t >= 1 ? to : _from, top: false),
            ]),
            if (t < 1)
              Column(mainAxisSize: MainAxisSize.min, children: [
                // Le haut de l'ancien se rabat vers le milieu…
                Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .004)
                    ..rotateX(firstHalf ? -angle : 0),
                  child: Opacity(
                      opacity: firstHalf ? 1 : 0,
                      child: _half(_from, top: true)),
                ),
                // …puis le bas du nouveau s'y pose.
                Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .004)
                    ..rotateX(firstHalf ? 0 : angle),
                  child: Opacity(
                      opacity: firstHalf ? 0 : 1, child: _half(to, top: false)),
                ),
              ]),
            // La ligne de pli, au milieu de la palette.
            Positioned.fill(
              child: Center(
                child: Container(
                    height: 1, color: AppColors.scrim.withValues(alpha: .6)),
              ),
            ),
          ]);
        },
      );
}
