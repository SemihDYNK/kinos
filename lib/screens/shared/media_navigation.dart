import 'package:kinos/models/items/images_models.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';

/// One identity per visible source, even when a title appears in several rows.
class MediaNavigationOrigin {
  ImageData? image;
}

class MediaNavigation extends StatefulWidget {
  const MediaNavigation(
      {required this.builder, this.previewImage, this.focusNode, super.key});
  final ImageData? previewImage;
  final FocusNode? focusNode;
  final WidgetBuilder builder;
  @override
  State<MediaNavigation> createState() => _MediaNavigationState();
}

class _MediaNavigationState extends State<MediaNavigation> {
  final _tag = MediaNavigationOrigin();
  final FocusNode _focus = FocusNode(debugLabel: 'media-origin');
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _tag.image = widget.previewImage;
    return MediaNavigationScope(
        tag: _tag,
        focusNode: widget.focusNode ?? _focus,
        child: Builder(builder: widget.builder));
  }
}

class MediaNavigationScope extends InheritedWidget {
  const MediaNavigationScope(
      {required this.tag, this.focusNode, required super.child, super.key});
  final Object? tag;
  final FocusNode? focusNode;
  static FocusNode? focusOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MediaNavigationScope>()
      ?.focusNode;
  static Object? tagOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaNavigationScope>()?.tag;
  @override
  bool updateShouldNotify(MediaNavigationScope oldWidget) =>
      oldWidget.tag != tag;
}

class MediaArtwork extends StatelessWidget {
  const MediaArtwork({required this.child, this.title = false, super.key});
  final Widget child;
  final bool title;
  @override
  Widget build(BuildContext context) {
    final tag = MediaNavigationScope.tagOf(context);
    if (tag == null || !AppMotion.enabled(context)) return child;
    return Hero(
        tag: (tag, title),
        transitionOnUserGestures: true,
        flightShuttleBuilder: (context, animation, direction, from, to) {
          final start = ((direction == HeroFlightDirection.push ? from : to)
                  .widget as Hero)
              .child;
          final end = ((direction == HeroFlightDirection.push ? to : from)
                  .widget as Hero)
              .child;
          final opacity = animation.drive(CurveTween(curve: AppMotion.easeOut));
          return Stack(fit: StackFit.expand, children: [
            FadeTransition(opacity: ReverseAnimation(opacity), child: start),
            FadeTransition(opacity: opacity, child: end),
          ]);
        },
        child: child);
  }
}

Future<void> openMediaDetails(BuildContext context, ItemBaseModel item) async {
  if (item.type != KinosItemType.movie &&
      item.type != KinosItemType.series &&
      item.type != KinosItemType.episode) {
    await item.navigateTo(context);
    return;
  }
  await pushMediaRoute(
      context,
      DetailsRoute(
          id: item is EpisodeModel ? item.parentId ?? item.id : item.id,
          item: item,
          tag: MediaNavigationScope.tagOf(context)));
}

Future<void> pushMediaRoute(BuildContext context, PageRouteInfo route) async {
  final focus = MediaNavigationScope.focusOf(context) ??
      FocusManager.instance.primaryFocus;
  final source = ModalRoute.of(context);
  await context.router.push(route);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted &&
        source?.isCurrent == true &&
        focus?.context != null &&
        focus!.canRequestFocus) {
      focus.requestFocus();
    }
  });
}
