import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_grab_status.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/arr/models/arr_release.dart';
import 'package:kinos/arr/providers/arr_search_providers.dart';
import 'package:kinos/arr/screens/widgets/arr_release_table.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';

/// Point d'entrée externe de la recherche interactive — le bloc titre
/// (série/film entier) et les lignes de `ArrSeasonSummaryList`
/// (saison/épisode) appellent ces méthodes directement plutôt que de
/// passer par un bouton interne à cette section, qui n'a donc plus de
/// sélecteur de portée à elle : elle ne garde que l'état et l'affichage
/// du tableau de résultats. Même style que `AnchoredPopoverController`.
class ArrDetailSearchSectionController {
  _ArrDetailSearchSectionState? _state;

  void _attach(_ArrDetailSearchSectionState state) => _state = state;
  void _detach(_ArrDetailSearchSectionState state) {
    if (identical(_state, state)) _state = null;
  }

  void expandMovie() => _state?._expandMovie();
  void expandSeries() => _state?._expandSeries();
  void expandSeason(int seasonNumber) => _state?._expandSeason(seasonNumber);
  void expandEpisode(ArrEpisode episode) => _state?._expandEpisode(episode);
}

/// Recherche interactive intégrée à la fiche détail — repliée par
/// défaut, un bouton "Recherche interactive" la déplie côté film (seule
/// portée possible). Côté série, aucun bouton ici : la portée (série
/// entière, saison, épisode) se choisit ailleurs sur la fiche — bloc
/// titre et liste des saisons — via [controller]. Toujours la même
/// [ArrReleaseTable] affichée, jamais de copie.
///
/// "Série entière" n'existe pas telle quelle côté API (`/api/v3/release`
/// n'accepte que `episodeId` ou `seriesId`+`seasonNumber`) : [_expandSeries]
/// fait un appel par saison surveillée, résultats fusionnés dans une
/// seule table.
class ArrDetailSearchSection extends ConsumerStatefulWidget {
  final ArrDetailEntry entry;
  final ArrDetailSearchSectionController? controller;

  const ArrDetailSearchSection({
    required this.entry,
    this.controller,
    super.key,
  });

  @override
  ConsumerState<ArrDetailSearchSection> createState() =>
      _ArrDetailSearchSectionState();
}

class _ArrDetailSearchSectionState
    extends ConsumerState<ArrDetailSearchSection> {
  bool _expanded = false;

  bool _releaseSearched = false;
  bool _releasesLoading = false;
  ArrApiError? _releasesError;
  String? _releasesErrorDetail;
  List<ArrRelease> _releases = const [];
  String? _releaseSearchLabel;
  final Map<String, ArrGrabStatus> _grabStatuses = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ArrDetailSearchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _expandMovie() {
    setState(() => _expanded = true);
    final movie = widget.entry.movie!;
    _searchReleases(
      label:
          movie.year != null ? '${movie.title} (${movie.year})' : movie.title,
      run: () => ref.read(radarrClientProvider)!.releasesForMovie(movie.id),
    );
  }

  void _expandSeason(int seasonNumber) {
    setState(() => _expanded = true);
    final series = widget.entry.series!;
    _searchReleases(
      label: '${series.title} — Saison $seasonNumber',
      run: () => ref
          .read(sonarrClientProvider)!
          .releasesForSeason(series.id, seasonNumber),
    );
  }

  void _expandEpisode(ArrEpisode episode) {
    setState(() => _expanded = true);
    final series = widget.entry.series!;
    _searchReleases(
      label:
          '${series.title} — S${episode.seasonNumber}E${episode.episodeNumber}',
      run: () => ref.read(sonarrClientProvider)!.releasesForEpisode(episode.id),
    );
  }

  /// Fan-out par saison surveillée, résultats fusionnés — aucune portée
  /// "série entière" côté API, cf. le commentaire de classe.
  Future<void> _expandSeries() async {
    final series = widget.entry.series!;
    final seasons =
        series.seasons.where((s) => s.monitored).toList()
          ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    setState(() {
      _expanded = true;
      _releaseSearched = true;
      _releasesLoading = true;
      _releasesError = null;
      _releases = const [];
      _releaseSearchLabel = '${series.title} — toutes les saisons surveillées';
      _grabStatuses.clear();
    });
    if (seasons.isEmpty) {
      if (mounted) setState(() => _releasesLoading = false);
      return;
    }
    final client = ref.read(sonarrClientProvider);
    if (client == null) {
      if (mounted) {
        setState(() {
          _releasesLoading = false;
          _releasesError = ArrApiError.unreachable;
          _releasesErrorDetail = 'Service non configuré';
        });
      }
      return;
    }
    final results = await Future.wait(
        seasons.map((s) => client.releasesForSeason(series.id, s.seasonNumber)));
    if (!mounted) return;
    final merged = <ArrRelease>[];
    ArrApiError? lastError;
    String? lastDetail;
    for (final result in results) {
      switch (result) {
        case ArrSuccess(:final data):
          merged.addAll(data);
        case ArrFailure(:final error, :final detail):
          lastError = error;
          lastDetail = detail;
      }
    }
    setState(() {
      _releasesLoading = false;
      _releases = merged;
      // Erreur seulement si aucune saison n'a renvoyé de résultat — un
      // échec isolé ne doit pas cacher les résultats des autres.
      if (merged.isEmpty && lastError != null) {
        _releasesError = lastError;
        _releasesErrorDetail = lastDetail;
      }
    });
  }

  Future<void> _searchReleases({
    required String label,
    required Future<ArrResult<List<ArrRelease>>> Function() run,
  }) async {
    setState(() {
      _releaseSearched = true;
      _releasesLoading = true;
      _releasesError = null;
      _releases = const [];
      _releaseSearchLabel = label;
      _grabStatuses.clear();
    });
    final result = await run();
    if (!mounted) return;
    setState(() {
      _releasesLoading = false;
      switch (result) {
        case ArrSuccess(:final data):
          _releases = data;
        case ArrFailure(:final error, :final detail):
          _releasesError = error;
          _releasesErrorDetail = detail;
      }
    });
  }

  Future<void> _grab(ArrRelease release) async {
    final client = widget.entry.isMovie
        ? ref.read(radarrClientProvider)
        : ref.read(sonarrClientProvider);
    if (client == null) return;
    setState(() => _grabStatuses[release.guid] = ArrGrabStatus.sending);
    final result = await client.grabRelease(
        guid: release.guid, indexerId: release.indexerId);
    if (!mounted) return;
    final succeeded = result is ArrSuccess;
    setState(() => _grabStatuses[release.guid] =
        succeeded ? ArrGrabStatus.success : ArrGrabStatus.failed);
    final message = switch (result) {
      ArrSuccess() => 'Envoyé au téléchargement : ${release.title}',
      ArrFailure(:final detail) =>
        'Échec de l\'envoi${detail != null ? ' — $detail' : ''}',
    };
    KinosSnack.show(message, context: context);
  }

  String _errorMessage(ArrApiError error, String? detail) {
    final base = switch (error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound => 'Route introuvable.',
      ArrApiError.serverError => "Erreur de l'indexeur ou du serveur.",
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return detail == null ? base : '$base $detail';
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      // Côté série, aucun bouton ici : la portée se choisit depuis le
      // bloc titre ou la liste des saisons (cf. commentaire de classe).
      if (!widget.entry.isMovie) return const SizedBox.shrink();
      return FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: _expandMovie,
        child: ExcludeFocus(
          child: OutlinedButton.icon(
            onPressed: _expandMovie,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Recherche interactive'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Recherche interactive',
                style: Theme.of(context).textTheme.headlineSmall),
            if (_releaseSearchLabel != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _releaseSearchLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!_releaseSearched)
          const SizedBox.shrink()
        else if (_releasesLoading)
          const _LoadingState(
              label: 'Recherche auprès des indexeurs (jusqu\'à 30 secondes)…')
        else if (_releasesError != null)
          _ErrorState(
              message: _errorMessage(_releasesError!, _releasesErrorDetail))
        else if (_releases.isEmpty)
          const _HintState(label: 'Aucun résultat.')
        else
          ArrReleaseTable(
            releases: _releases,
            grabStatuses: _grabStatuses,
            onGrab: _grab,
          ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String label;
  const _LoadingState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  final String label;
  const _HintState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
