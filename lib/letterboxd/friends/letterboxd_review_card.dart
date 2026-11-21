import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kinos/screens/shared/media/external_urls.dart' as links;
import 'package:kinos/theme/app_theme.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_providers.dart';
import 'letterboxd_reviews.dart';

/// Une critique à lire : son auteur (un ami, ou soi) et la critique.
typedef ReviewEntry = ({
  LetterboxdFriend author,
  LetterboxdReview review,
  bool mine
});

/// Ouvre la critique [index] de [entries] : la carte naît de [origin] (la
/// cellule de l'ami, en coordonnées globales) et s'y range en se fermant.
Future<void> showLetterboxdReview(BuildContext context,
    {required List<ReviewEntry> entries,
    required int index,
    required Rect origin}) {
  final motion = AppMotion.enabled(context);
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Fermer la critique',
    barrierColor: AppColors.scrim.withValues(alpha: .6),
    transitionDuration: motion ? AppDurations.heroSlide : Duration.zero,
    reverseTransitionDuration:
        motion ? AppDurations.heroSlide * .8 : Duration.zero,
    pageBuilder: (context, animation, _) => _ReviewOverlay(
        animation: animation, origin: origin, entries: entries, index: index),
  ));
}

class _ReviewOverlay extends StatefulWidget {
  const _ReviewOverlay(
      {required this.animation,
      required this.origin,
      required this.entries,
      required this.index});
  final Animation<double> animation;
  final Rect origin;
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - AppSpacing.xl * 2)
        .clamp(0.0, AppDetailLayout.reviewCardWidth);
    final height = size.height * AppDetailLayout.reviewCardHeightFraction;
    final target = Rect.fromCenter(
        center: size.center(Offset.zero), width: width, height: height);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) {
            final t = _curve.value;
            // La cellule grandit jusqu'à la carte (container transform) ;
            // le contenu n'apparaît qu'une fois la forme presque posée.
            final rect = Rect.lerp(widget.origin, target, t)!;
            final radius = lerpDouble(AppRadii.control, AppRadii.sheet, t)!;
            return Stack(children: [
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: ColoredBox(
                    color: AppColors.surfaceHigh,
                    child: Opacity(
                      opacity: const Interval(.45, 1).transform(t),
                      // Mise en page à la taille finale, réduite pendant le
                      // trajet : le texte ne se recompose pas à chaque image.
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                            width: target.width,
                            height: target.height,
                            child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
          child: AnimatedSwitcher(
            duration: AppMotion.enabled(context)
                ? AppDurations.heroSlide
                : Duration.zero,
            switchInCurve: AppMotion.easeOut,
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(_index);
              final from =
                  incoming ? _direction.toDouble() : -_direction.toDouble();
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                    position:
                        Tween(begin: Offset(from * .08, 0), end: Offset.zero)
                            .animate(animation),
                    child: child),
              );
            },
            child: _ReviewPage(
              key: ValueKey(_index),
              entry: widget.entries[_index],
              position: '${_index + 1} / ${widget.entries.length}',
              onPrevious: _index > 0 ? () => _go(-1) : null,
              onNext: _index < widget.entries.length - 1 ? () => _go(1) : null,
            ),
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClipOval(
            child: SizedBox.square(
              dimension: AppDetailLayout.reviewAvatarSize,
              child: ColoredBox(
                color: AppColors.surface,
                child: author.avatarUrl == null
                    ? Center(
                        child: Text(author.name.characters.first.toUpperCase(),
                            style: text.titleMedium))
                    : Image.network(author.avatarUrl!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.entry.mine ? 'Votre critique' : author.name,
                  style:
                      text.titleLarge?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                  [
                    if (review.rating != null) letterboxdStars(review.rating!),
                    if (review.date != null)
                      DateFormat('d MMMM y', locale).format(review.date!),
                    if (review.likes > 0) '${review.likes} j\'aime',
                  ].join('  ·  '),
                  style: secondary),
            ]),
          ),
          Text(widget.position, style: secondary),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: body == null
              ? _SpoilerVeil(onReveal: () => setState(() => _revealed = true))
              : SingleChildScrollView(
                  child: Text(body,
                      style: text.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppDetailLayout.reviewTextSize,
                          height: AppDetailLayout.reviewTextHeight)),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          _CardButton(
              icon: Icons.chevron_left_rounded,
              label: 'Précédente',
              onActivate: widget.onPrevious),
          const SizedBox(width: AppSpacing.xs),
          _CardButton(
              icon: Icons.chevron_right_rounded,
              label: 'Suivante',
              onActivate: widget.onNext),
          const Spacer(),
          _CardButton(
              icon: Icons.open_in_new_rounded,
              label: 'Lire sur Letterboxd',
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
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Cette critique contient des spoilers.',
            style: text.titleMedium?.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.md),
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
      required this.label,
      required this.onActivate,
      this.autofocus = false});
  final IconData icon;
  final String label;
  final VoidCallback? onActivate;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onActivate != null;
    final color = enabled ? AppColors.textPrimary : AppColors.textDisabled;
    return FocusRing(
      autofocus: autofocus,
      borderRadius: AppRadii.controlBorder,
      onActivate: onActivate,
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: Border.all(
                color: enabled ? AppColors.borderStrong : AppColors.border),
            borderRadius: AppRadii.controlBorder),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: AppDetailLayout.friendStarSize * 1.5, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: color)),
          ]),
        ),
      ),
    );
  }
}
