import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kinos/screens/shared/media/external_urls.dart' as links;
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_providers.dart';
import 'letterboxd_reviews.dart';

/// Une critique à lire : son auteur (un ami, ou soi) et la critique.
typedef ReviewEntry = ({
  LetterboxdFriend author,
  LetterboxdReview review,
  bool mine
});

/// Ouvre la critique [index] de [entries] : la tuile naît de la photo de
/// l'ami ([origin], sa cellule en coordonnées globales), s'ouvre en cercle
/// depuis elle et s'y referme.
///
/// [originOf] donne la cellule d'un ami : en passant d'une critique à
/// l'autre, la tuile glisse jusqu'à sa photo.
Future<void> showLetterboxdReview(BuildContext context,
    {required List<ReviewEntry> entries,
    required int index,
    required Rect origin,
    Rect? Function(String username)? originOf}) {
  final motion = AppMotion.enabled(context);
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Fermer la critique',
    barrierColor: AppColors.scrim.withValues(alpha: .25),
    transitionDuration: motion ? AppDurations.heroSlide : Duration.zero,
    reverseTransitionDuration:
        motion ? AppDurations.heroSlide * .7 : Duration.zero,
    pageBuilder: (context, animation, _) => _ReviewOverlay(
        animation: animation,
        origin: origin,
        originOf: originOf,
        entries: entries,
        index: index),
  ));
}

class _ReviewOverlay extends StatefulWidget {
  const _ReviewOverlay(
      {required this.animation,
      required this.origin,
      this.originOf,
      required this.entries,
      required this.index});
  final Animation<double> animation;
  final Rect origin;
  final Rect? Function(String username)? originOf;
  final List<ReviewEntry> entries;
  final int index;

  @override
  State<_ReviewOverlay> createState() => _ReviewOverlayState();
}

class _ReviewOverlayState extends State<_ReviewOverlay> {
  late int _index = widget.index;
  // Sens du dernier passage d'une critique à l'autre, pour le glissement.
  int _direction = 0;

  late final _curve = CurvedAnimation(
      parent: widget.animation,
      curve: AppMotion.easeOut,
      reverseCurve: Curves.easeInCubic);

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.entries.length) return;
    setState(() {
      _index = next;
      _direction = delta;
    });
  }

  // Dernière cellule connue : un ami hors de la rangée repliée garde la
  // tuile où elle est.
  late Rect _anchor = widget.origin;

  static Offset _avatarOf(Rect cell) => Offset(cell.center.dx,
      cell.top + AppSpacing.xxs + AppDetailLayout.friendAvatarSize / 2);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final motion = AppMotion.enabled(context);
    _anchor = widget.originOf?.call(widget.entries[_index].author.username) ??
        _anchor;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        // La tuile glisse d'une photo à l'autre.
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _avatarOf(_anchor)),
          duration: motion ? AppDurations.heroSlide : Duration.zero,
          curve: AppMotion.easeOut,
          builder: (context, avatar, tile) {
            final layout = _TileLayout(avatar: avatar);
            // Le cercle s'arrête aux coins de la tuile, pas de la fenêtre :
            // toute sa course se voit.
            final rect = layout.tileRect(size, layout.maxChildSize(size));
            final reach = [
              rect.topLeft,
              rect.topRight,
              rect.bottomLeft,
              rect.bottomRight
            ].map((c) => (c - avatar).distance).reduce((a, b) => a > b ? a : b);
            return AnimatedBuilder(
              animation: _curve,
              builder: (context, child) {
                final t = _curve.value;
                return Transform.scale(
                  // Un léger agrandissement depuis la photo, avec le cercle.
                  scale: lerpDouble(.9, 1, t)!,
                  origin: avatar - size.center(Offset.zero),
                  child: ClipPath(
                    clipper: _CircleReveal(
                        avatar,
                        lerpDouble(
                            AppDetailLayout.friendAvatarSize / 2, reach, t)!),
                    child: Opacity(
                        opacity: const Interval(0, .6, curve: Curves.easeOut)
                            .transform(t),
                        child: child),
                  ),
                );
              },
              child: CustomSingleChildLayout(delegate: layout, child: tile),
            );
          },
          child: FrostedSurface(
            child: AnimatedSize(
              duration: motion ? AppDurations.unroll : Duration.zero,
              curve: AppMotion.easeOut,
              alignment: Alignment.topLeft,
              child: AnimatedSwitcher(
                duration: motion ? AppDurations.unroll : Duration.zero,
                switchInCurve: AppMotion.easeOut,
                layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, if (current != null) current]),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_index);
                  final from =
                      incoming ? _direction.toDouble() : -_direction.toDouble();
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                        position: Tween(
                                begin: Offset(from * .06, 0), end: Offset.zero)
                            .animate(animation),
                        child: child),
                  );
                },
                child: _ReviewPage(
                  key: ValueKey(_index),
                  entry: widget.entries[_index],
                  position: '${_index + 1} / ${widget.entries.length}',
                  onPrevious: _index > 0 ? () => _go(-1) : null,
                  onNext:
                      _index < widget.entries.length - 1 ? () => _go(1) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal(this.center, this.radius);
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleReveal old) =>
      old.center != center || old.radius != radius;
}

/// Pose la tuile pour que sa photo couvre celle de l'ami, puis la garde
/// dans la fenêtre.
class _TileLayout extends SingleChildLayoutDelegate {
  const _TileLayout({required this.avatar});
  final Offset avatar;

  /// La plus grande tuile possible dans une fenêtre de taille [size].
  Size maxChildSize(Size size) {
    final c = getConstraintsForChild(BoxConstraints.loose(size));
    return Size(c.maxWidth, c.maxHeight);
  }

  /// Où se pose une tuile de taille [child].
  Rect tileRect(Size size, Size child) =>
      getPositionForChild(size, child) & child;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = (constraints.maxWidth - AppSpacing.md * 2)
        .clamp(0.0, AppDetailLayout.reviewTileWidth);
    return BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: constraints.maxHeight *
            AppDetailLayout.reviewTileMaxHeightFraction);
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    const inset = AppSpacing.md + AppDetailLayout.friendAvatarSize / 2;
    final x = (avatar.dx - inset).clamp(
        AppSpacing.md,
        (size.width - child.width - AppSpacing.md)
            .clamp(AppSpacing.md, double.infinity));
    final y = (avatar.dy - inset).clamp(
        AppSpacing.md,
        (size.height - child.height - AppSpacing.md)
            .clamp(AppSpacing.md, double.infinity));
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(_TileLayout old) => old.avatar != avatar;
}

class _ReviewPage extends ConsumerStatefulWidget {
  const _ReviewPage(
      {required this.entry,
      required this.position,
      this.onPrevious,
      this.onNext,
      super.key});
  final ReviewEntry entry;
  final String position;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  ConsumerState<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<_ReviewPage> {
  late bool _revealed = !widget.entry.review.spoilers;

  @override
  Widget build(BuildContext context) {
    final review = widget.entry.review;
    final author = widget.entry.author;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final body = _revealed
        ? ref.watch(letterboxdReviewTextProvider(review)).valueOrNull ??
            review.excerpt
        : null;
    final secondary = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    final url =
        'https://letterboxd.com${review.path ?? '/${author.username}/film/${review.slug}/'}';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              // À la place exacte de la photo de l'ami.
              ClipOval(
                child: SizedBox.square(
                  dimension: AppDetailLayout.friendAvatarSize,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: author.avatarUrl == null
                        ? Center(
                            child: Text(
                                author.name.characters.first.toUpperCase(),
                                style: text.titleMedium))
                        : Image.network(author.avatarUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.entry.mine ? 'Votre critique' : author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium
                              ?.copyWith(color: AppColors.textPrimary)),
                      Text(
                          [
                            if (review.rating != null)
                              letterboxdStars(review.rating!),
                            if (review.date != null)
                              DateFormat('d MMM y', locale)
                                  .format(review.date!),
                            if (review.likes > 0) '${review.likes} j\'aime',
                          ].join('  ·  '),
                          style: secondary),
                    ]),
              ),
              Text(widget.position, style: secondary),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: body == null
                  ? _SpoilerVeil(
                      onReveal: () => setState(() => _revealed = true))
                  : SingleChildScrollView(
                      child: Text(body,
                          style: text.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppDetailLayout.reviewTextSize,
                              height: AppDetailLayout.reviewTextHeight)),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              _CardButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Critique précédente',
                  onActivate: widget.onPrevious),
              const SizedBox(width: AppSpacing.xxs),
              _CardButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Critique suivante',
                  onActivate: widget.onNext),
              const Spacer(),
              _CardButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'Letterboxd',
                  tooltip: 'Lire sur Letterboxd',
                  onActivate: () => links.launchUrl(context, url)),
            ]),
          ]),
    );
  }
}

class _SpoilerVeil extends StatelessWidget {
  const _SpoilerVeil({required this.onReveal});
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Cette critique contient des spoilers.',
            style: text.bodyMedium?.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        _CardButton(
            icon: Icons.visibility_outlined,
            label: 'Afficher quand même',
            autofocus: true,
            onActivate: onReveal),
      ]),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton(
      {required this.icon,
      this.label,
      this.tooltip,
      required this.onActivate,
      this.autofocus = false});
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onActivate;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onActivate != null;
    final color = enabled ? AppColors.textPrimary : AppColors.textDisabled;
    final button = FocusRing(
      autofocus: autofocus,
      borderRadius: AppRadii.controlBorder,
      onActivate: onActivate,
      child: DecoratedBox(
        decoration: BoxDecoration(
            border:
                Border.all(color: enabled ? AppGlass.border : AppColors.border),
            borderRadius: AppRadii.controlBorder),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: label == null ? AppSpacing.xs : AppSpacing.sm,
              vertical: AppSpacing.xxs),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: AppDetailLayout.friendStarSize * 1.5, color: color),
            if (label != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              Text(label!,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color)),
            ],
          ]),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
