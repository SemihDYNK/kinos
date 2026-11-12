import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/theme/app_theme.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_providers.dart';
import 'letterboxd_friends_store.dart';

/// « Vos amis sur Letterboxd » : avatars et notes des comptes suivis qui ont
/// noté ce film, dans le bandeau sous les pistes, visible sans défiler.
/// Rien n'est affiché sans compte relié ni note d'ami.
class LetterboxdFriendsSection extends ConsumerStatefulWidget {
  const LetterboxdFriendsSection({required this.tmdbId, super.key});
  final String tmdbId;

  @override
  ConsumerState<LetterboxdFriendsSection> createState() => _SectionState();
}

class _SectionState extends ConsumerState<LetterboxdFriendsSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Rafraîchit en arrière-plan si la dernière synchronisation est vieille.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(letterboxdFriendsSyncProvider.notifier);
      controller.sync();
      controller.ensureAvatar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final film =
        ref.watch(letterboxdFriendsFilmProvider(widget.tmdbId)).valueOrNull;
    if (film == null || (film.ratings.isEmpty && film.mine == null)) {
      return const SizedBox.shrink();
    }
    final ratings = film.ratings;
    final mine = film.mine;
    final average = ratings.isEmpty
        ? 0.0
        : ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;
    // Ta cellule prend la place d'un ami : la rangée reste sur une ligne.
    final limit = AppDetailLayout.friendsVisible - (mine != null ? 1 : 0);
    final folded = ratings.length > limit;
    final visible = _expanded ? ratings : ratings.take(limit).toList();
    final account = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    final count = ratings.length;
    final friends = Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Ta photo et ta note d'abord, puis une barre verticale, puis les
        // amis.
        if (mine != null)
          _MyRatingCell(rating: mine, slug: film.slug, account: account),
        if (mine != null && ratings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: SizedBox(
                width: 1,
                height: AppDetailLayout.friendDividerHeight,
                child: ColoredBox(
                    color: AppColors.textPrimary.withValues(alpha: .35))),
          ),
        for (final rating in visible)
          _FriendRatingCell(rating: rating, slug: film.slug),
        if (folded)
          _MoreCell(
              label: _expanded ? 'Réduire' : '+${count - visible.length}',
              tooltip: _expanded
                  ? 'Revenir à une rangée'
                  : 'Afficher les ${count - visible.length} autres notes',
              onActivate: () => setState(() => _expanded = !_expanded)),
      ],
    );
    // Texte sur image : textPrimary, secondaire à 75 % (cf. CLAUDE.md).
    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: AppDetailLayout.movieSynopsisWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: ratings.isEmpty
                    ? 'Votre note sur Letterboxd'
                    : 'Vos amis sur Letterboxd',
                style: text.titleSmall?.copyWith(color: AppColors.textPrimary)),
            if (ratings.isNotEmpty)
              TextSpan(
                  text: '  ·  $count ${count > 1 ? 'notes' : 'note'} · moyenne '
                      '${(average / 2).toStringAsFixed(1).replaceAll('.', ',')} / 5',
                  style: text.bodySmall?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: .75))),
          ])),
          ...[
            const SizedBox(height: AppSpacing.xs),
            // Dépliage animé, sauf sans mouvement (clavier, mouvement réduit) :
            // jamais d'AnimatedSize à durée nulle.
            if (AppMotion.enabled(context))
              AnimatedSize(
                  duration: AppDurations.unroll,
                  curve: AppMotion.easeOut,
                  alignment: Alignment.topLeft,
                  child: friends)
            else
              friends,
          ],
        ],
      ),
    );
  }
}

class _FriendRatingCell extends StatelessWidget {
  const _FriendRatingCell({required this.rating, required this.slug});
  final FriendRating rating;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final friend = rating.friend;
    final stars = letterboxdStars(rating.rating);
    return Tooltip(
      message: '${friend.name} · $stars',
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        // Ouvre l'avis (ou la note) de l'ami sur letterboxd.com.
        onActivate: () => launchUrl(
            context, 'https://letterboxd.com/${friend.username}/film/$slug/'),
        child: Semantics(
          label: '${friend.name}, ${rating.rating / 2} sur 5',
          excludeSemantics: true,
          child: SizedBox(
            width: AppDetailLayout.friendCellWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Column(
                children: [
                  _Avatar(friend: friend),
                  const SizedBox(height: AppSpacing.xxs),
                  // Étoiles de taille fixe : la note se lit à leur nombre,
                  // jamais à leur taille.
                  _Stars(rating: rating.rating),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.friend});
  final LetterboxdFriend friend;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
        child: Text(friend.name.characters.first.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium));
    final url = friend.avatarUrl;
    return SizedBox.square(
      dimension: AppDetailLayout.friendAvatarSize,
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.surfaceHigh,
          child: url == null
              ? initial
              : Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => initial),
        ),
      ),
    );
  }
}

class _MoreCell extends StatelessWidget {
  const _MoreCell(
      {required this.label, required this.tooltip, required this.onActivate});
  final String label;
  final String tooltip;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onActivate,
          child: SizedBox(
            width: AppDetailLayout.friendCellWidth,
            height: AppDetailLayout.friendAvatarSize + AppSpacing.lg,
            child: Center(
                child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.textPrimary)),
            )),
          ),
        ),
      );
}

/// Note sur 10 en étoiles pleines et demi-étoile, toutes de la même taille
/// ([AppDetailLayout.friendStarSize]).
class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rating ~/ 2; i++)
            const Icon(Icons.star_rounded,
                size: AppDetailLayout.friendStarSize,
                color: AppColors.textPrimary),
          if (rating.isOdd)
            const Icon(Icons.star_half_rounded,
                size: AppDetailLayout.friendStarSize,
                color: AppColors.textPrimary),
        ],
      );
}

/// Ta photo de profil et ta note, comme une cellule d'ami : ouvre ta page
/// du film sur letterboxd.com quand ton pseudo est connu.
class _MyRatingCell extends StatelessWidget {
  const _MyRatingCell(
      {required this.rating, required this.slug, required this.account});
  final int rating;
  final String slug;
  final LetterboxdFriendsAccount? account;

  @override
  Widget build(BuildContext context) {
    final username = account?.username;
    return Tooltip(
      message: 'Vous · ${letterboxdStars(rating)}',
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: username == null
            ? null
            : () => launchUrl(
                context, 'https://letterboxd.com/$username/film/$slug/'),
        child: Semantics(
          label: 'Votre note, ${rating / 2} sur 5',
          excludeSemantics: true,
          child: SizedBox(
            width: AppDetailLayout.friendCellWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Column(
                children: [
                  // Ta photo Letterboxd, dans le même rond que les amis.
                  _Avatar(
                      friend: LetterboxdFriend(
                          username: username ?? '',
                          name: username ?? 'Vous',
                          avatarUrl: account?.avatarUrl)),
                  const SizedBox(height: AppSpacing.xxs),
                  _Stars(rating: rating),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
