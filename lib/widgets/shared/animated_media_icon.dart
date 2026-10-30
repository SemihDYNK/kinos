import 'package:flutter/material.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/theme/app_theme.dart';

class _Selection extends ImplicitlyAnimatedWidget {
  const _Selection(
      {required this.selected, required this.builder, required super.duration})
      : super(curve: AppMotion.easeOut);
  final bool selected;
  final Widget Function(double) builder;
  @override
  AnimatedWidgetBaseState<_Selection> createState() => _SelectionState();
}

class _SelectionState extends AnimatedWidgetBaseState<_Selection> {
  Tween<double>? _progress;
  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _progress = visitor(_progress, widget.selected ? 1.0 : 0.0,
            (dynamic value) => Tween<double>(begin: value as double))
        as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_progress!.evaluate(animation));
}

Widget _selection(BuildContext context, bool selected,
    Widget Function(double progress) builder) {
  if (!AppMotion.enabled(context)) return builder(selected ? 1 : 0);
  return _Selection(
      selected: selected,
      builder: builder,
      duration: selected ? AppDurations.selection : AppDurations.hover);
}

class AnimatedFavouriteIcon extends StatefulWidget {
  const AnimatedFavouriteIcon({required this.selected, this.size, super.key});
  final bool selected;
  final double? size;

  @override
  State<AnimatedFavouriteIcon> createState() => _AnimatedFavouriteIconState();
}

class _AnimatedFavouriteIconState extends State<AnimatedFavouriteIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  Animation<double> _scale = const AlwaysStoppedAnimation(1);
  late Animation<double> _fill =
      AlwaysStoppedAnimation(widget.selected ? 1 : 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.enabled(context)) _settle();
  }

  void _settle() {
    _controller.stop();
    _scale = const AlwaysStoppedAnimation(1);
    _fill = AlwaysStoppedAnimation(widget.selected ? 1 : 0);
  }

  @override
  void didUpdateWidget(covariant AnimatedFavouriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (!AppMotion.enabled(context)) {
      _settle();
      return;
    }
    final startScale = _scale.value;
    final startFill = _fill.value;
    TweenSequenceItem<double> segment(double from, double to, double weight) =>
        TweenSequenceItem(
          tween: Tween(begin: from, end: to)
              .chain(CurveTween(curve: AppMotion.easeOut)),
          weight: weight,
        );
    _scale = TweenSequence<double>(widget.selected
            ? [
                segment(startScale, 1 + AppMotion.heartLift, 30),
                segment(1 + AppMotion.heartLift, AppMotion.heartRecoil, 30),
                segment(AppMotion.heartRecoil, AppMotion.heartSettle, 20),
                segment(AppMotion.heartSettle, 1, 20),
              ]
            : [
                segment(startScale, AppMotion.heartRecoil, 45),
                segment(AppMotion.heartRecoil, 1, 55),
              ])
        .animate(_controller);
    _fill = Tween<double>(begin: startFill, end: widget.selected ? 1 : 0)
        .chain(CurveTween(curve: AppMotion.easeOut))
        .animate(_controller);
    _controller.duration = widget.selected
        ? AppDurations.favourite
        : AppDurations.favouriteRemoval;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Stack(alignment: Alignment.center, children: [
              Opacity(
                  opacity: 1 - _fill.value,
                  child: Icon(AppIcons.favourite, size: widget.size)),
              Opacity(
                  opacity: _fill.value,
                  child: Icon(AppIcons.favouriteSelected, size: widget.size)),
            ]),
          ));
}

class AnimatedWatchedIcon extends StatelessWidget {
  const AnimatedWatchedIcon(
      {required this.selected,
      this.circled = true,
      this.size,
      this.color,
      this.semanticLabel,
      super.key});
  final bool selected;
  final bool circled;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final extent = size ?? theme.size ?? AppNavigation.iconSize;
    final iconColor = color ?? theme.color ?? AppColors.textPrimary;
    final ink = iconColor.withValues(alpha: iconColor.a * (theme.opacity ?? 1));
    return Semantics(
        label: semanticLabel,
        child: _selection(context, selected, (progress) {
          if (progress == 1 || (progress == 0 && circled)) {
            final icon = circled
                ? progress == 1
                    ? AppIcons.watchedSelected
                    : AppIcons.watchedCircle
                : AppIcons.watched;
            return Icon(icon, size: extent, color: iconColor);
          }
          return CustomPaint(
              size: Size.square(extent),
              painter: _WatchedPainter(progress, ink, circled));
        }));
  }
}

class _WatchedPainter extends CustomPainter {
  const _WatchedPainter(this.progress, this.color, this.circled);
  final double progress;
  final Color color;
  final bool circled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / AppMotion.iconGrid);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppMotion.iconStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (circled) {
      canvas.drawCircle(const Offset(12, 12), 10, pen);
      canvas.drawCircle(const Offset(12, 12), 10,
          Paint()..color = color.withValues(alpha: color.a * progress));
      pen.color = Color.lerp(color, AppColors.background, progress)!;
    }
    final check = circled
        ? (Path()
          ..moveTo(7, 12)
          ..lineTo(10.5, 15.5)
          ..lineTo(17, 8.5))
        : (Path()
          ..moveTo(5, 12)
          ..lineTo(10, 17)
          ..lineTo(20, 6));
    final metric = check.computeMetrics().first;
    if (progress > 0) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), pen);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatchedPainter old) =>
      old.progress != progress || old.color != color || old.circled != circled;
}
