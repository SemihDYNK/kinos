import 'package:auto_route/auto_route.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

Route<T> mediaPageRoute<T>(
    BuildContext context, Widget child, AutoRoutePage<T> page) {
  final args = page.routeData.args;
  final episode = args is DetailsRouteArgs && args.item is EpisodeModel;
  final enabled = AppMotion.enabled(context);
  return PageRouteBuilder<T>(
      settings: page,
      maintainState: page.maintainState,
      fullscreenDialog: page.fullscreenDialog,
      transitionDuration: enabled
          ? (episode ? AppDurations.pageTransition : AppDurations.heroSlide)
          : Duration.zero,
      reverseTransitionDuration:
          enabled ? AppDurations.pageTransition : Duration.zero,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: mediaRouteTransition);
}

Route<T> catalogPageRoute<T>(
        BuildContext context, Widget child, AutoRoutePage<T> page) =>
    PageRouteBuilder<T>(
        settings: page,
        maintainState: page.maintainState,
        transitionDuration: AppMotion.enabled(context)
            ? AppDurations.pageTransition
            : Duration.zero,
        reverseTransitionDuration: AppMotion.enabled(context)
            ? AppDurations.pageTransition
            : Duration.zero,
        pageBuilder: (_, __, ___) => child,
        transitionsBuilder: catalogRouteTransition);

/// Chrome remains outside the route; only its page moves.
Widget mediaRouteTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  if (!AppMotion.enabled(context)) {
    return HeroMode(enabled: false, child: child);
  }
  final eased = animation.drive(CurveTween(curve: AppMotion.easeOut));
  return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: eased.drive(Tween(
            begin: const Offset(0, AppMotion.pageTravelFraction),
            end: Offset.zero)),
        child: child,
      ));
}

Widget catalogRouteTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  if (!AppMotion.enabled(context)) return child;
  final eased = animation.drive(CurveTween(curve: AppMotion.easeOut));
  return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: eased.drive(Tween(
            begin: const Offset(AppMotion.pageTravelFraction, 0),
            end: Offset.zero)),
        child: child,
      ));
}

class CatalogPageMotion extends StatefulWidget {
  const CatalogPageMotion(
      {required this.index, required this.child, super.key});
  final int index;
  final Widget child;
  @override
  State<CatalogPageMotion> createState() => _CatalogPageMotionState();
}

class _CatalogPageMotionState extends State<CatalogPageMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: AppDurations.pageTransition, value: 1);
  double _direction = 1;
  @override
  void didUpdateWidget(CatalogPageMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      if (AppMotion.enabled(context)) {
        _controller.forward(
            from: _controller.isAnimating ? _controller.value : 0);
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.enabled(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = AppMotion.easeOut.transform(_controller.value);
        return Opacity(
            key: const ValueKey('catalog-page-opacity'),
            opacity: progress,
            child: Transform.translate(
                offset: Offset((1 - progress) * AppSpacing.lg * _direction, 0),
                child: child));
      });
}
