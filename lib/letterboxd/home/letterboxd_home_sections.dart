import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart';
import 'package:kinos/providers/connectivity_provider.dart'
    show offlineStateProvider;
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/theme/app_theme.dart';

import 'letterboxd_home_providers.dart';
import 'letterboxd_watchlist_screen.dart';

/// Les quatre rangées Letterboxd de l'accueil, juste après « Pour vous » :
/// conseils des amis, watchlist disponible, watchlist à demander, tirage
/// du Top 500. Chacune n'apparaît que si elle a du contenu ; les films à
/// demander supposent un service Seerr sur le profil.
class LetterboxdHomeSections extends ConsumerStatefulWidget {
  const LetterboxdHomeSections({required this.contentPadding, super.key});
  final EdgeInsets contentPadding;

  @override
  ConsumerState<LetterboxdHomeSections> createState() => _SectionsState();
}

class _SectionsState extends ConsumerState<LetterboxdHomeSections> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(letterboxdHomeRefreshProvider.notifier).ensure();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Les notes des amis arrivent : les conseils peuvent enfin se calculer.
    ref.listen(letterboxdFriendsSyncProvider.select((s) => s.running),
        (was, running) {
      if (was == true && !running) {
        ref.read(letterboxdHomeRefreshProvider.notifier).ensure();
      }
    });
    ref.watch(letterboxdHeroPreloadProvider);
    if (ref.watch(offlineStateProvider)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final rows = ref.watch(letterboxdHomeRowsProvider).valueOrNull;
    if (rows == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final canRequest = ref.watch(
        userProvider.select((u) => u?.seerrCredentials?.isConfigured ?? false));

    List<RecommendationTile> tiles(List<LetterboxdHomeEntry> entries) => [
          for (final entry in entries)
            if (entry.item case final item?)
              RecommendationTile.jellyfin(item: item)
            else if (canRequest)
              if (int.tryParse(entry.film.tmdbId) case final tmdbId?)
                RecommendationTile.request(
                    tmdbId: tmdbId,
                    title: entry.film.title,
                    year: entry.film.year,
                    posterUrl: entry.film.posterUrl),
        ];

    void seeWatchlist() => openLetterboxdWatchlist(context);
    final sections = [
      ('Vos amis conseillent', tiles(rows.friends), null),
      ('Votre watchlist', tiles(rows.watchlistLibrary), seeWatchlist),
      ('Watchlist · à demander', tiles(rows.watchlistRequest), seeWatchlist),
      ('Les grands films de Letterboxd', tiles(rows.top), null),
    ];
    return SliverMainAxisGroup(slivers: [
      for (final (title, list, onSeeAll) in sections)
        if (list.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: RecommendationRowGrid(
                key: ValueKey(title),
                title: title,
                tiles: list,
                onSeeAll: onSeeAll,
                contentPadding: widget.contentPadding),
          ),
    ]);
  }
}
