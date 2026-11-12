import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/theme/app_theme.dart';

import 'letterboxd_home_providers.dart';

Future<void> openLetterboxdWatchlist(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LetterboxdWatchlistScreen()));

/// Toute la watchlist Letterboxd : les films disponibles, puis ceux à
/// demander. Échap ou la flèche reviennent à l'accueil.
class LetterboxdWatchlistScreen extends ConsumerWidget {
  const LetterboxdWatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(letterboxdWatchlistProvider).valueOrNull;
    final canRequest = ref.watch(
        userProvider.select((u) => u?.seerrCredentials?.isConfigured ?? false));
    final text = Theme.of(context).textTheme;
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding);

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

    final library = tiles(watchlist?.library ?? const []);
    final request = tiles(watchlist?.request ?? const []);
    final pending = watchlist?.pending ?? 0;

    Widget heading(String title, int count) => SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl, bottom: AppSpacing.sm),
          sliver: SliverToBoxAdapter(
              child: Text.rich(TextSpan(children: [
            TextSpan(text: title, style: text.headlineMedium),
            TextSpan(
                text: '  $count',
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ]))),
        );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(slivers: [
            SliverPadding(
              padding: padding.copyWith(top: AppSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Tooltip(
                    message: 'Retour · Échap',
                    child: FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        child: Icon(Icons.arrow_back, semanticLabel: 'Retour'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text('Votre watchlist', style: text.displaySmall)),
                ]),
              ),
            ),
            if (watchlist == null)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()))
            else ...[
              if (library.isNotEmpty) ...[
                heading('Disponibles', library.length),
                RecommendationTileGrid(tiles: library, contentPadding: padding),
              ],
              if (request.isNotEmpty) ...[
                heading('À demander', request.length),
                RecommendationTileGrid(tiles: request, contentPadding: padding),
              ],
              if (pending > 0)
                SliverPadding(
                  padding: padding.copyWith(top: AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                        '$pending films encore en cours de chargement depuis '
                        'Letterboxd.',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                ),
            ],
            const SliverPadding(
                padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
          ]),
        ),
      ),
    );
  }
}
