import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'package:kinos/theme/app_theme.dart';

/// The same wordmark survives the route change while the destination paints.
class StartupCurtain extends StatefulWidget {
  const StartupCurtain({this.onRevealed, this.ready = true, super.key});

  final VoidCallback? onRevealed;
  final bool ready;

  @override
  State<StartupCurtain> createState() => _StartupCurtainState();
}

class _StartupCurtainState extends State<StartupCurtain>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.startupReveal,
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
    if (!widget.ready && !timedOut) {
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
      if (mounted) widget.onRevealed?.call();
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
    final progress =
        CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);
    const logo = Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: KinosWordmark(width: AppBrand.startupWordmarkWidth),
      ),
    );
    if (exiting && motion) {
      return AnimatedBuilder(
        animation: _controller,
        child: logo,
        builder: (context, child) => ClipPath(
          clipper: StartupApertureClipper(
              AppMotion.startupAperture.transform(_controller.value)),
          child: ColoredBox(
            color: AppColors.background,
            child: Transform.translate(
              offset: Offset(
                    (.5 - AppBrand.wordmarkOAnchor.dx) *
                        AppBrand.startupWordmarkWidth,
                    (.5 - AppBrand.wordmarkOAnchor.dy) *
                        AppBrand.startupWordmarkWidth /
                        AppBrand.wordmarkAspectRatio,
                  ) *
                  AppMotion.startupWordmarkMove.transform(_controller.value),
              child: child,
            ),
          ),
        ),
      );
    }
    return FadeTransition(
        opacity: exiting
            ? ReverseAnimation(progress)
            : const AlwaysStoppedAnimation(1),
        child: ColoredBox(
          color: AppColors.background,
          child: FadeTransition(
            opacity: exiting ? const AlwaysStoppedAnimation(1) : progress,
            child: motion && !exiting
                ? ScaleTransition(
                    scale: Tween(begin: AppMotion.startupScale, end: 1.0)
                        .animate(progress),
                    child: logo,
                  )
                : logo,
          ),
        ));
  }
}

class StartupApertureClipper extends CustomClipper<Path> {
  const StartupApertureClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: radius * progress,
      ));
  }

  @override
  bool shouldReclip(StartupApertureClipper oldClipper) =>
      oldClipper.progress != progress;
}
