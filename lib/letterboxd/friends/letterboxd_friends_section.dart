import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/appear_in.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_providers.dart';
import 'letterboxd_review_card.dart';
import 'letterboxd_reviews.dart';
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

  // Un repère par cellule : la tuile d'une critique suit la photo de l'ami
  // qu'elle montre.
  final _cells = <String, GlobalKey>{};
  GlobalKey _cell(String username) =>
      _cells.putIfAbsent(username, () => GlobalKey(debugLabel: username));

  /// Rectangle d'une cellule à l'écran, null si elle n'est pas affichée
  /// (rangée repliée).
  Rect? _cellRect(String username) {
    final box = _cells[username]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

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
    final scored = [
      for (final r in ratings)
        if (r.rating > 0) r.rating
    ];
    final average =
        scored.isEmpty ? 0.0 : scored.reduce((a, b) => a + b) / scored.length;
    // Ta cellule prend la place d'un ami : la rangée reste sur une ligne.
    final limit = AppDetailLayout.friendsVisible - (mine != null ? 1 : 0);
    final folded = ratings.length > limit;
    final visible = _expanded ? ratings : ratings.take(limit).toList();
    final account = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    final count = ratings.length;
    // Les critiques écrites, dans l'ordre de la rangée : la sienne d'abord.
    final myReview = account == null ? null : film.reviews[account.username];
    final entries = <ReviewEntry>[
      if (myReview != null)
        (
          author: LetterboxdFriend(
              username: account!.username,
              name: account.username,
              avatarUrl: account.avatarUrl),
          review: myReview,
          mine: true
        ),
      for (final r in ratings)
        if (film.reviews[r.friend.username] case final review?)
          (author: r.friend, review: review, mine: false),
    ];
    final written = entries.where((e) => !e.mine).length;
    void openReview(BuildContext cell, String username) {
      final box = cell.findRenderObject() as RenderBox?;
      if (box == null) return;
      showLetterboxdReview(context,
          entries: entries,
          index: entries.indexWhere((e) => e.author.username == username),
          origin: box.localToGlobal(Offset.zero) & box.size,
          originOf: _cellRect);
    }

    final friends = Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Ta photo et ta note d'abord, puis une barre verticale, puis les
        // amis.
        if (mine != null)
          _MyRatingCell(
              key: _cell(account?.username ?? ''),
              rating: mine,
              slug: film.slug,
              account: account,
              review: myReview,
              onOpenReview: (cell) => openReview(cell, account!.username)),
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
          _FriendRatingCell(
              key: _cell(rating.friend.username),
              rating: rating,
              slug: film.slug,
              review: film.reviews[rating.friend.username],
              onOpenReview: (cell) => openReview(cell, rating.friend.username)),
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
    // Les notes arrivent après la fiche : elles entrent en fondu.
    return AppearIn(
        child: ConstrainedBox(
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
                  text: '  ·  $count ${count > 1 ? 'amis' : 'ami'}'
                      '${written > 0 ? ' · $written ${written > 1 ? 'critiques' : 'critique'}' : ''}'
                      ' · moyenne '
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
    ));
  }
}

/// Infobulle d'une cellule : le nom, la note, et le début de la critique.
String _cellTooltip(String name, int rating, LetterboxdReview? review) {
  final excerpt = review == null || review.spoilers
      ? null
      : review.excerpt.split('\n').first;
  return [
    name,
    if (rating > 0) letterboxdStars(rating),
    if (review?.spoilers ?? false) 'critique (spoilers)',
    if (excerpt != null && excerpt.isNotEmpty)
      '« ${excerpt.length > 90 ? '${excerpt.substring(0, 90).trimRight()}…' : excerpt} »',
  ].join(' · ');
}

class _FriendRatingCell extends StatelessWidget {
  const _FriendRatingCell(
      {super.key,
      required this.rating,
      required this.slug,
      this.review,
      required this.onOpenReview});
  final FriendRating rating;
  final String slug;
  final LetterboxdReview? review;
  final void Function(BuildContext cell) onOpenReview;

  @override
  Widget build(BuildContext context) {
    final friend = rating.friend;
    return Tooltip(
      message: _cellTooltip(friend.name, rating.rating, review),
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        // Une critique s'ouvre dans l'app ; une note seule, sur
        // letterboxd.com.
        onActivate: review != null
            ? () => onOpenReview(context)
            : () => launchUrl(context,
                'https://letterboxd.com/${friend.username}/film/$slug/'),
        child: Semantics(
          label: '${friend.name}, ${rating.rating / 2} sur 5'
              '${review != null ? ', a écrit une critique' : ''}',
          excludeSemantics: true,
          child: SizedBox(
            width: AppDetailLayout.friendCellWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Column(
                children: [
                  _Avatar(friend: friend, review: review != null),
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
  const _Avatar({required this.friend, this.review = false});
  final LetterboxdFriend friend;

  /// Une critique écrite : une pastille-guillemet au coin de la photo.
  final bool review;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
        child: Text(friend.name.characters.first.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium));
    final url = friend.avatarUrl;
    final photo = SizedBox.square(
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
    if (!review) return photo;
    return Stack(clipBehavior: Clip.none, children: [
      photo,
      const Positioned(
        right: -AppSpacing.xxs,
        bottom: -AppSpacing.xxs,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: AppColors.textPrimary, shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxs / 2),
            child: Icon(Icons.format_quote_rounded,
                size: AppDetailLayout.reviewMarkSize,
                color: AppColors.background),
          ),
        ),
      ),
    ]);
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
      {super.key,
      required this.rating,
      required this.slug,
      required this.account,
      this.review,
      required this.onOpenReview});
  final int rating;
  final String slug;
  final LetterboxdFriendsAccount? account;
  final LetterboxdReview? review;
  final void Function(BuildContext cell) onOpenReview;

  @override
  Widget build(BuildContext context) {
    final username = account?.username;
    return Tooltip(
      message: _cellTooltip('Vous', rating, review),
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: review != null
            ? () => onOpenReview(context)
            : username == null
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
                      review: review != null,
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
