import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/startup_mark.dart';
import 'package:kinos/theme/app_theme.dart';

/// Début de l'attente de l'accueil, partagé par l'écran de démarrage et le
/// rideau qui lui succède : le trait d'attente continue sans à-coup de l'un
/// à l'autre.
DateTime? _waitingSince;

/// The assembled signature remains in place until the destination paints.
class StartupCurtain extends StatefulWidget {
  const StartupCurtain(
      {this.onRevealed,
      this.onLogoReady,
      this.onOpening,
      this.ready = true,
      super.key});

  final VoidCallback? onRevealed;
  final VoidCallback? onLogoReady;

  /// Le rideau commence à s'ouvrir (l'accueil a peint sa première image).
  final VoidCallback? onOpening;
  final bool ready;

  @override
  State<StartupCurtain> createState() => _StartupCurtainState();
}

class _StartupCurtainState extends State<StartupCurtain>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.onRevealed == null
        ? AppDurations.startupLogo
        : AppDurations.startupReveal,
  );

  bool _started = false;
  bool _assembled = false;
  Timer? _readinessTimeout;

  bool get _exiting => widget.onRevealed != null;

  // Launch motion is not pointer feedback: keyboard input must not suppress it.
  bool get _motionEnabled =>
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startWhenReady();
  }

  @override
  void didUpdateWidget(StartupCurtain oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startWhenReady();
  }

  void _startWhenReady({bool timedOut = false}) {
    if (_started) return;
    if (_exiting && !widget.ready && !timedOut) {
      _waitingSince ??= DateTime.now();
      // Keep navigation accessible even if the destination fails to mount.
      _readinessTimeout ??= Timer(AppDurations.startupLoadTimeout,
          () => _startWhenReady(timedOut: true));
      return;
    }
    _readinessTimeout?.cancel();
    _started = true;
    // Start the clock only after the destination has actually painted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_exiting) {
        setState(() {});
        widget.onOpening?.call();
      }
      if (!_motionEnabled) {
        _controller.value = 1;
      } else {
        try {
          await _controller.forward().orCancel;
        } on TickerCanceled {
          return;
        }
      }
      if (!mounted) return;
      if (_exiting) {
        _waitingSince = null;
        widget.onRevealed!.call();
      } else {
        // Le signe est assemblé : ce qui suit est de l'attente.
        _waitingSince ??= DateTime.now();
        setState(() => _assembled = true);
        widget.onLogoReady?.call();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _readinessTimeout?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Le signe et, dessous sans le déplacer, le trait d'attente.
  Widget _markWithWait(Widget mark, {required bool waiting}) => Stack(
        alignment: Alignment.center,
        children: [
          mark,
          Transform.translate(
            offset: const Offset(
                0, AppBrand.startupMarkSize / 2 + AppBrand.startupWaitGap),
            child: _StartupWaitLine(active: waiting && _motionEnabled),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final motion = _motionEnabled;
    const mark = StartupMark(progress: 1);
    if (_exiting && motion) {
      return LayoutBuilder(builder: (context, constraints) {
        final notch = AppBrand.startupMarkNotch * AppBrand.startupMarkSize;
        final centre = constraints.biggest.center(Offset.zero) + notch;
        return AnimatedBuilder(
          animation: _controller,
          child: _markWithWait(mark, waiting: !_started),
          builder: (context, child) {
            final opening =
                AppMotion.startupAperture.transform(_controller.value);
            final feather =
                AppBrand.startupApertureFeather * math.sin(math.pi * opening);
            final dive = AppMotion.startupExitDive.transform(_controller.value);
            return Stack(fit: StackFit.expand, children: [
              ClipPath(
                clipper: StartupApertureClipper(opening,
                    feather: feather, centre: centre),
                child: ColoredBox(
                  color: AppColors.background,
                  child: Opacity(
                    opacity: 1 -
                        AppMotion.startupMarkFade.transform(_controller.value),
                    // La caméra plonge dans le creux du K : le signe grandit
                    // autour du point d'où part l'ouverture.
                    child: Center(
                      child: Transform.scale(
                        scale: 1 + (AppMotion.startupExitZoom - 1) * dive,
                        origin: notch,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                  child: CustomPaint(
                painter: _StartupApertureEdge(opening, feather, centre),
              )),
            ]);
          },
        );
      });
    }
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: _exiting || !motion
            ? _markWithWait(mark, waiting: _exiting ? !_started : _assembled)
            : AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => _markWithWait(
                    StartupMark(progress: _controller.value),
                    waiting: _assembled),
              ),
      ),
    );
  }
}

/// Trait d'attente sous le signe : invisible pendant
/// [AppDurations.startupWaitDelay], puis un court segment balaie lentement
/// un fil discret. Il compte depuis le début de l'attente ([_waitingSince]),
/// pas depuis sa propre création : il ne repart pas de zéro quand le rideau
/// succède à l'écran de démarrage.
class _StartupWaitLine extends StatefulWidget {
  const _StartupWaitLine({required this.active});
  final bool active;

  @override
  State<_StartupWaitLine> createState() => _StartupWaitLineState();
}

class _StartupWaitLineState extends State<_StartupWaitLine>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker((elapsed) {
    setState(() => _elapsed = elapsed);
  });

  /// Attente déjà écoulée quand ce trait a démarré (l'écran de démarrage
  /// l'a peut-être commencée), puis le temps du ticker.
  Duration _before = Duration.zero;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_StartupWaitLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !_ticker.isActive) {
      final since = _waitingSince;
      _before =
          since == null ? Duration.zero : DateTime.now().difference(since);
      _elapsed = Duration.zero;
      _ticker.start();
    }
    if (!widget.active && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox(width: AppBrand.startupWaitWidth, height: 1);
    }
    final elapsed = _before + _elapsed - AppDurations.startupWaitDelay;
    final visible =
        (elapsed.inMicroseconds / AppDurations.startupWaitFade.inMicroseconds)
            .clamp(0.0, 1.0);
    final sweep = elapsed.isNegative
        ? 0.0
        : (elapsed.inMicroseconds %
                AppDurations.startupWaitSweep.inMicroseconds) /
            AppDurations.startupWaitSweep.inMicroseconds;
    return Opacity(
      opacity: visible,
      child: CustomPaint(
        size: const Size(AppBrand.startupWaitWidth, 1),
        painter: _WaitLinePainter(Curves.easeInOut.transform(sweep)),
      ),
    );
  }
}

class _WaitLinePainter extends CustomPainter {
  const _WaitLinePainter(this.sweep);
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = AppColors.textPrimary
              .withValues(alpha: AppBrand.startupWaitTrackOpacity));
    // Le segment entre et sort du fil : il part avant le bord gauche et
    // finit après le bord droit, découpé au fil.
    const segment = AppBrand.startupWaitSegment;
    final left = -segment + (size.width + segment) * sweep;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
        Rect.fromLTWH(left, 0, segment, size.height),
        Paint()
          ..color = AppColors.textPrimary
              .withValues(alpha: AppBrand.startupWaitOpacity));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WaitLinePainter oldDelegate) =>
      oldDelegate.sweep != sweep;
}

class StartupApertureClipper extends CustomClipper<Path> {
  const StartupApertureClipper(this.progress, {this.feather = 0, this.centre});
  final double progress;
  final double feather;

  /// Centre de l'ouverture ; par défaut, celui de l'écran.
  final Offset? centre;

  Offset centreIn(Size size) => centre ?? size.center(Offset.zero);

  /// Rayon qui découvre tout l'écran depuis [centreIn] : la distance au
  /// coin le plus éloigné.
  double fullRadius(Size size) => _farthestCorner(size, centreIn(size));

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(
        center: centreIn(size),
        radius: fullRadius(size) * progress + feather,
      ));
  }

  @override
  bool shouldReclip(StartupApertureClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.feather != feather ||
      oldClipper.centre != centre;
}

double _farthestCorner(Size size, Offset centre) => [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - centre).distance).reduce(math.max);

// Feather the mask itself without sampling or blurring the live home layers.
class _StartupApertureEdge extends CustomPainter {
  const _StartupApertureEdge(this.progress, this.feather, this.centre);
  final double progress, feather;
  final Offset centre;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || feather <= 0) return;
    final radius = _farthestCorner(size, centre) * progress;
    final outer = radius + feather;
    final bounds = Rect.fromCircle(center: centre, radius: outer);
    canvas.drawCircle(
        centre,
        outer + AppSpacing.xxs,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.background.withValues(alpha: 0),
              AppColors.background.withValues(alpha: .5),
              AppColors.background,
            ],
            stops: [math.max(0, radius - feather) / outer, radius / outer, 1],
          ).createShader(bounds));
  }

  @override
  bool shouldRepaint(_StartupApertureEdge oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.feather != feather ||
      oldDelegate.centre != centre;
}
