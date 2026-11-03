import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/startup_mark.dart';
import 'package:kinos/theme/app_theme.dart';

/// The assembled signature remains in place until the destination paints.
class StartupCurtain extends StatefulWidget {
  const StartupCurtain(
      {this.onRevealed, this.onLogoReady, this.ready = true, super.key});

  final VoidCallback? onRevealed;
  final VoidCallback? onLogoReady;
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
  Timer? _readinessTimeout;

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
    if (widget.onRevealed != null && !widget.ready && !timedOut) {
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
      if (!_motionEnabled) {
        _controller.value = 1;
      } else {
        try {
          await _controller.forward().orCancel;
        } on TickerCanceled {
          return;
        }
      }
      if (mounted) {
        if (widget.onRevealed != null) {
          widget.onRevealed!.call();
        } else {
          widget.onLogoReady?.call();
        }
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

  @override
  Widget build(BuildContext context) {
    final exiting = widget.onRevealed != null;
    final motion = _motionEnabled;
    const logo = Center(child: StartupMark(progress: 1));
    if (exiting && motion) {
      return AnimatedBuilder(
        animation: _controller,
        child: logo,
        builder: (context, child) {
          final opening =
              AppMotion.startupAperture.transform(_controller.value);
          final feather =
              AppBrand.startupApertureFeather * math.sin(math.pi * opening);
          return Stack(fit: StackFit.expand, children: [
            ClipPath(
              clipper: StartupApertureClipper(opening, feather: feather),
              child: ColoredBox(
                color: AppColors.background,
                child: Opacity(
                  opacity: 1 -
                      AppMotion.startupMarkFade.transform(_controller.value),
                  child: child,
                ),
              ),
            ),
            IgnorePointer(
                child: CustomPaint(
              painter: _StartupApertureEdge(opening, feather),
            )),
          ]);
        },
      );
    }
    return ColoredBox(
      color: AppColors.background,
      child: exiting || !motion
          ? logo
          : AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Center(
                child: StartupMark(progress: _controller.value),
              ),
            ),
    );
  }
}

class StartupApertureClipper extends CustomClipper<Path> {
  const StartupApertureClipper(this.progress, {this.feather = 0});
  final double progress;
  final double feather;

  @override
  Path getClip(Size size) {
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: radius * progress + feather,
      ));
  }

  @override
  bool shouldReclip(StartupApertureClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.feather != feather;
}

// Feather the mask itself without sampling or blurring the live home layers.
class _StartupApertureEdge extends CustomPainter {
  const _StartupApertureEdge(this.progress, this.feather);
  final double progress, feather;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || feather <= 0) return;
    final centre = size.center(Offset.zero);
    final radius = centre.distance * progress;
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
      oldDelegate.progress != progress || oldDelegate.feather != feather;
}
