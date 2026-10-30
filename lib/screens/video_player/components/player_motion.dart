import 'dart:async';
import 'package:kinos/util/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/theme/app_theme.dart';

class PlayerControlsMotion extends StatelessWidget {
  const PlayerControlsMotion(
      {required this.visible,
      required this.child,
      this.hiddenOffset = const Offset(0, AppSpacing.sm),
      super.key});
  final bool visible;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = AppMotion.enabled(context);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: visible ? 1 : 0),
            duration: !enabled
                ? Duration.zero
                : visible
                    ? AppDurations.popover
                    : AppDurations.pageTransition,
            curve: AppMotion.easeOut,
            child: child,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: enabled ? hiddenOffset * (1 - value) : Offset.zero,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerPlaybackIcon extends StatelessWidget {
  const PlayerPlaybackIcon({required this.playing, super.key});
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final icon =
        Icon(playing ? AppIcons.pause : AppIcons.play, key: ValueKey(playing));
    if (!AppMotion.enabled(context)) return icon;
    return AnimatedSwitcher(
      duration: AppDurations.popover,
      reverseDuration: AppDurations.hover,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation
              .drive(CurveTween(curve: AppMotion.posterReveal))
              .drive(Tween(begin: AppMotion.posterActionScale, end: 1.0)),
          child: child,
        ),
      ),
      child: icon,
    );
  }
}

class PlayerBufferingIndicator extends StatefulWidget {
  const PlayerBufferingIndicator({required this.buffering, super.key});
  final bool buffering;
  @override
  State<PlayerBufferingIndicator> createState() =>
      _PlayerBufferingIndicatorState();
}

class _PlayerBufferingIndicatorState extends State<PlayerBufferingIndicator> {
  Timer? _delay;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant PlayerBufferingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buffering != oldWidget.buffering) _update();
  }

  void _update() {
    _delay?.cancel();
    if (!widget.buffering) {
      _visible = false;
      return;
    }
    _delay = Timer(AppDurations.bufferingDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerControlsMotion(
        visible: _visible,
        child: Center(
            child: SizedBox.square(
          dimension: AppMotion.iconGrid * 2,
          child: TickerMode(
              enabled: _visible,
              child: CircularProgressIndicator(
                value: AppMotion.enabled(context)
                    ? null
                    : AppPlayerStyle.staticLoadingProgress,
                color: AppColors.textPrimary,
                backgroundColor: AppColors.progressTrack,
                strokeWidth: AppMotion.iconStroke,
                semanticsLabel: context.localized.loading,
              )),
        )),
      );
}
