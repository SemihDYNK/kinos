import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:kinos/screens/shared/startup_aurora.dart';
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
      this.intro = false,
      this.word = true,
      this.tint,
      this.onPieces,
      this.onClap,
      this.onWindow,
      super.key});

  /// Les pièces de l'intro commencent à arriver des bords (pour leurs
  /// souffles).
  final VoidCallback? onPieces;

  /// Le clap de l'intro (pour son son), au moment où l'animation le
  /// franchit.
  final VoidCallback? onClap;

  /// À l'ouverture après l'intro : la fenêtre du faisceau commence à
  /// s'élargir (pour le souffle).
  final VoidCallback? onWindow;

  /// Intro avec « KINOS » après le clap (premier lancement de la session) ;
  /// sans lui, elle s'arrête au K assemblé et l'ouverture part du K centré.
  final bool word;

  /// Dominante du premier film du bandeau (intro longue) : le fond passe
  /// du noir à un dégradé de cette couleur au clap. `null` tant qu'elle
  /// n'est pas prête : un repli neutre, puis la vraie couleur en fondu.
  final Color? tint;

  /// Avance maximale de l'animation par image affichée (cf.
  /// [AppDurations.startupFrameCap]) ; `null` dans les tests, où le temps
  /// avance par grands sauts.
  @visibleForTesting
  static Duration? frameCap = AppDurations.startupFrameCap;

  /// Attente maximale du calme avant l'ouverture (cf.
  /// [AppDurations.startupSettleMax]) ; zéro dans les tests.
  @visibleForTesting
  static Duration settleMax = AppDurations.startupSettleMax;

  /// Version longue de l'assemblage (premier lancement de la session). À
  /// l'ouverture, le rideau part du mot posé et plonge dans le creux du K
  /// à sa place dans le mot.
  final bool intro;

  final VoidCallback? onRevealed;
  final VoidCallback? onLogoReady;

  /// Le rideau commence à s'ouvrir (l'accueil a peint sa première image).
  final VoidCallback? onOpening;
  final bool ready;

  @override
  State<StartupCurtain> createState() => _StartupCurtainState();
}

class _StartupCurtainState extends State<StartupCurtain>
    with TickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.onRevealed != null
        ? (widget.intro
            ? AppDurations.startupIntroReveal
            : AppDurations.startupReveal)
        : widget.intro
            ? (widget.word
                ? AppDurations.startupIntro
                : AppDurations.startupIntroShort)
            : AppDurations.startupLogo,
  );

  bool _started = false;
  bool _assembled = false;
  Timer? _readinessTimeout;

  /// Horloge de l'animation : elle n'avance que d'au plus
  /// [StartupCurtain.frameCap] par image affichée. L'accueil bloque le
  /// rendu une centaine de millisecondes en se construisant ; une horloge
  /// libre aurait continué pendant ce gel, et l'ouverture aurait sauté son
  /// début (le faisceau surgissait d'un coup). Elle ralentit un instant au
  /// lieu de sauter.
  Ticker? _clock;
  Completer<bool>? _run;

  Future<bool> _play() {
    final run = _run = Completer<bool>();
    final duration = _controller.duration!.inMicroseconds;
    Duration? last;
    _clock?.dispose();
    _clock = createTicker((elapsed) {
      var step = last == null ? Duration.zero : elapsed - last!;
      last = elapsed;
      final cap = StartupCurtain.frameCap;
      if (cap != null && step > cap) step = cap;
      final previous = _controller.value;
      final next = previous + step.inMicroseconds / duration;
      _soundAt(previous, next, duration);
      if (next >= 1) {
        _finish(true);
      } else {
        _controller.value = next;
      }
    })
      ..start();
    return run.future;
  }

  /// Les sons de l'intro (le clap, puis à l'ouverture la fenêtre qui
  /// s'élargit), au moment où l'animation les franchit, avec
  /// [AppDurations.startupSoundLead] d'avance pour la latence audio. Passée
  /// avant le clap, l'intro n'en joue pas.
  void _soundAt(double previous, double next, int duration) {
    if (!widget.intro) return;
    final lead = AppDurations.startupSoundLead.inMicroseconds / duration;
    if (_exiting) {
      // La fenêtre du faisceau commence à s'élargir.
      final window = AppMotion.startupIntroBeamOpen.begin - lead;
      if (previous < window && next >= window) widget.onWindow?.call();
      return;
    }
    // Fraction de toute l'intro où tombe un instant de l'assemblage.
    double atAssembly(double t) =>
        widget.word ? t * AppMotion.startupIntroAssemblyEnd : t;
    // Les pièces arrivent des bords (le fichier enchaîne les trois souffles
    // aux écarts de leurs arrivées) : il part avec la première.
    final pieces = atAssembly(AppMotion.startupIntroArrivals
            .map((i) => i.begin)
            .reduce(math.min)) -
        lead;
    if (previous < pieces && next >= pieces) widget.onPieces?.call();
    final onClap = widget.onClap;
    if (onClap == null) return;
    final clap = (widget.word
            ? AppMotion.startupIntroAssemblyEnd * AppMotion.startupIntroClap
            : AppMotion.startupIntroClap) -
        AppDurations.startupSoundLead.inMicroseconds / duration;
    if (previous < clap && next >= clap) onClap();
  }

  void _finish(bool completed) {
    _clock?.stop();
    if (completed) _controller.value = 1;
    final run = _run;
    _run = null;
    if (run != null && !run.isCompleted) run.complete(completed);
  }

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
    // Start the clock only after the destination has actually painted, and
    // has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _settleThen(_begin));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// L'accueil qui vient d'apparaître occupe le fil principal (fin de
  /// construction, données, images) : une ouverture lancée tout de suite
  /// sautait des images. Le rideau attend que les images sortent à temps
  /// ([AppDurations.startupSettleFrame], plusieurs d'affilée), au plus
  /// [StartupCurtain.settleMax], en gardant le mot posé.
  Ticker? _settle;

  void _settleThen(VoidCallback start) {
    final max = StartupCurtain.settleMax;
    if (!mounted) return;
    if (!_exiting || !_motionEnabled || max == Duration.zero) {
      start();
      return;
    }
    Duration? last;
    var calm = 0;
    _settle?.dispose();
    _settle = createTicker((elapsed) {
      if (last != null) {
        calm =
            elapsed - last! <= AppDurations.startupSettleFrame ? calm + 1 : 0;
      }
      last = elapsed;
      if (calm >= AppMotion.startupSettleFrames || elapsed >= max) {
        _settle?.stop();
        start();
      }
    })
      ..start();
  }

  Future<void> _begin() async {
    if (!mounted) return;
    if (_exiting) {
      setState(() {});
      widget.onOpening?.call();
    }
    if (!_motionEnabled) {
      _controller.value = 1;
    } else {
      if (!await _play()) return;
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
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Une touche ou un clic pendant l'assemblage l'amènent à son terme : le
  /// K assemblé, comme s'il venait de finir.
  bool _skip() {
    if (_exiting || _clock?.isActive != true) return false;
    // Termine l'animation sans l'annuler : la suite (onLogoReady) se joue.
    _finish(true);
    return true;
  }

  @override
  void dispose() {
    _readinessTimeout?.cancel();
    _finish(false);
    _clock?.dispose();
    _settle?.dispose();
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
    final mark =
        StartupMark(progress: 1, intro: widget.intro, word: widget.word);
    if (_exiting && motion && widget.intro) {
      // Les branches du K, en projecteur, ouvrent sur l'accueil.
      return Stack(fit: StackFit.expand, children: [
        const StartupAuroraTicker(),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: StartupIntroBeam(_controller.value,
                markSize: AppBrand.startupMarkSize,
                tint: widget.tint ?? AppColors.heroFallback,
                word: widget.word),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: const Offset(
                0, AppBrand.startupMarkSize / 2 + AppBrand.startupWaitGap),
            child: _StartupWaitLine(active: !_started),
          ),
        ),
      ]);
    }
    if (_exiting && motion) {
      return LayoutBuilder(builder: (context, constraints) {
        final notch = StartupMark.notchOffset(AppBrand.startupMarkSize,
            intro: widget.intro, word: widget.word);
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
    return Focus(
      autofocus: !_exiting,
      includeSemantics: false,
      onKeyEvent: (_, event) => event is KeyDownEvent && _skip()
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      // La touche et le clic pour passer restent hors de l'arbre
      // d'accessibilité : leurs nœuds plein écran y absorberaient le
      // libellé du K.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _skip,
        child: ColoredBox(
          color: AppColors.background,
          child: Stack(fit: StackFit.expand, children: [
            if (widget.intro && motion && !_exiting)
              _ClapBloom(
                  progress: _controller, tint: widget.tint, word: widget.word),
            Center(
              child: _exiting || !motion
                  ? _markWithWait(mark,
                      waiting: _exiting ? !_started : _assembled)
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => _markWithWait(
                          StartupMark(
                              progress: _controller.value,
                              intro: widget.intro,
                              word: widget.word),
                          waiting: _assembled),
                    ),
            ),
          ]),
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

/// Aurore qui naît au clap de l'intro longue (cf. [StartupAurora]) : ses
/// taches de couleur s'allument et grandissent, puis dérivent. Si la
/// dominante arrive tard, elle part d'un repli neutre et y passe en fondu.
class _ClapBloom extends StatelessWidget {
  const _ClapBloom(
      {required this.progress, required this.tint, required this.word});
  final Animation<double> progress;
  final Color? tint;
  final bool word;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const StartupAuroraTicker(),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: tint ?? AppColors.heroFallback),
          duration: AppMotion.startupTintFade,
          curve: AppMotion.easeOut,
          builder: (context, color, _) => CustomPaint(
            painter: _AuroraPainter(
                progress: progress,
                word: word,
                colors: StartupAurora.colorsFor(color!)),
          ),
        ),
      ]);
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(
      {required this.progress, required this.colors, required this.word})
      : super(repaint: Listenable.merge([progress, StartupAurora.time]));
  final Animation<double> progress;
  final List<Color> colors;
  final bool word;

  @override
  void paint(Canvas canvas, Size size) {
    // Sans le mot, l'intro s'arrête à la fin de l'assemblage.
    final bloom = AppMotion.startupIntroBloom.transform(word
        ? progress.value
        : progress.value * AppMotion.startupIntroAssemblyEnd);
    if (bloom <= 0) return;
    StartupAurora.paint(canvas, Offset.zero & size,
        colors: colors, intensity: bloom);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.progress != progress;
}
