import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_row.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/util/localization_helper.dart';

/// Rangées de découverte Seerr — tendances, films/séries populaires, à
/// venir — sourcées de [seerrDashboardProvider] (`/api/v1/discover/*`,
/// déjà utilisé par le tableau de bord "Demandes"). Sert de contenu par
/// défaut à l'écran de recherche/découverte tant qu'aucune recherche
/// n'est en cours, exactement comme la page d'accueil de Jellyseerr —
/// jamais un écran vide en attendant une saisie.
class SeerrDiscoverRows extends ConsumerWidget {
  final EdgeInsets contentPadding;

  const SeerrDiscoverRows({required this.contentPadding, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(seerrDashboardProvider);

    final sections = [
      if (dashboard.trending.isNotEmpty)
        SeerrPosterRow(
          label: context.localized.trending,
          posters: dashboard.trending,
          contentPadding: contentPadding,
          onLabelClick: () => context.pushRoute(SeerrSearchRoute(mode: SeerrSearchMode.trending)),
        ),
      if (dashboard.popularMovies.isNotEmpty)
        SeerrPosterRow(
          label: context.localized.popularMovies,
          posters: dashboard.popularMovies,
          contentPadding: contentPadding,
          onLabelClick: () => context.pushRoute(SeerrSearchRoute(mode: SeerrSearchMode.discoverMovies)),
        ),
      if (dashboard.popularSeries.isNotEmpty)
        SeerrPosterRow(
          label: context.localized.popularSeries,
          posters: dashboard.popularSeries,
          contentPadding: contentPadding,
          onLabelClick: () => context.pushRoute(SeerrSearchRoute(mode: SeerrSearchMode.discoverTv)),
        ),
      if (dashboard.expectedMovies.isNotEmpty)
        SeerrPosterRow(
          label: context.localized.expectedMovies,
          posters: dashboard.expectedMovies,
          contentPadding: contentPadding,
          onLabelClick: () => context.pushRoute(
            SeerrSearchRoute(mode: SeerrSearchMode.discoverMovies, yearGte: DateTime.now().year),
          ),
        ),
      if (dashboard.expectedSeries.isNotEmpty)
        SeerrPosterRow(
          label: context.localized.expectedSeries,
          posters: dashboard.expectedSeries,
          contentPadding: contentPadding,
          onLabelClick: () => context.pushRoute(
            SeerrSearchRoute(mode: SeerrSearchMode.discoverTv, yearGte: DateTime.now().year),
          ),
        ),
    ];

    if (sections.isEmpty) {
      // Vide signifie ici "pas encore chargé" dans l'immense majorité des
      // cas (le fetch se déclenche à l'ouverture de l'écran) — un vrai
      // Jellyseerr sans aucun contenu à découvrir serait une anomalie
      // serveur, pas un état à distinguer finement ici.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }
}
