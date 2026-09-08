import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_grab_status.dart';
import 'package:fladder/arr/models/arr_library_entry.dart';
import 'package:fladder/arr/models/arr_library_item.dart';
import 'package:fladder/arr/models/arr_release.dart';
import 'package:fladder/arr/providers/arr_search_providers.dart';
import 'package:fladder/arr/screens/widgets/arr_release_table.dart';
import 'package:fladder/arr/screens/widgets/arr_season_episode_picker.dart';
import 'package:fladder/arr/services/arr_api_client.dart';
import 'package:fladder/arr/widgets/arr_desktop_scope.dart';
import 'package:fladder/routes/auto_router.gr.dart';
import 'package:fladder/screens/shared/fladder_notification_overlay.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/router_extension.dart';

/// Recherche interactive — bibliothèque Radarr/Sonarr existante, choix
/// d'un film ou d'une série (puis saison ou épisode), résultats des
/// indexeurs, envoi au téléchargement. Cf. CLAUDE.md § notes Arr (aucun
/// mode salon, aucune navigation télécommande — tableau à colonnes,
/// illisible en 10-foot).
///
/// Route à part entière (poussée depuis [ArrHomeScreen], raccourci
/// "Recherche" de sa barre du haut) — porte donc elle-même son cadre
/// d'écran (fond, retrait sous la barre latérale, bouton retour), plutôt
/// que de dépendre d'un appelant qui les fournirait.
@RoutePage()
class ArrSearchScreen extends ConsumerStatefulWidget {
  const ArrSearchScreen({super.key});

  @override
  ConsumerState<ArrSearchScreen> createState() => _ArrSearchScreenState();
}

class _ArrSearchScreenState extends ConsumerState<ArrSearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  bool _librarySearched = false;
  bool _libraryLoading = false;
  ArrApiError? _libraryError;
  String? _libraryErrorDetail;
  List<ArrLibraryEntry> _libraryResults = const [];

  ArrLibraryEntry? _selected;
  bool _episodesLoading = false;
  List<ArrEpisode> _episodes = const [];

  bool _releaseSearched = false;
  bool _releasesLoading = false;
  ArrApiError? _releasesError;
  String? _releasesErrorDetail;
  List<ArrRelease> _releases = const [];
  String? _releaseSearchLabel;

  final Map<String, ArrGrabStatus> _grabStatuses = {};

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _librarySearched = false;
        _libraryResults = const [];
        _libraryError = null;
      });
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _runLibrarySearch(query));
  }

  Future<void> _runLibrarySearch(String query) async {
    setState(() {
      _libraryLoading = true;
      _libraryError = null;
    });
    final radarr = ref.read(radarrClientProvider);
    final sonarr = ref.read(sonarrClientProvider);
    final results = <ArrLibraryEntry>[];
    ArrApiError? firstError;
    String? firstDetail;

    if (radarr != null) {
      final result = await radarr.searchMovies(query);
      switch (result) {
        case ArrSuccess(:final data):
          results.addAll(data.map(ArrLibraryEntry.movie));
        case ArrFailure(:final error, :final detail):
          firstError ??= error;
          firstDetail ??= detail;
      }
    }
    if (sonarr != null) {
      final result = await sonarr.searchSeries(query);
      switch (result) {
        case ArrSuccess(:final data):
          results.addAll(data.map(ArrLibraryEntry.series));
        case ArrFailure(:final error, :final detail):
          firstError ??= error;
          firstDetail ??= detail;
      }
    }
    results
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _libraryLoading = false;
      _librarySearched = true;
      _libraryResults = results;
      // Une erreur ne s'affiche que si elle a empêché TOUT résultat — un
      // service en échec ne doit pas cacher les résultats de l'autre.
      _libraryError = results.isEmpty ? firstError : null;
      _libraryErrorDetail = firstDetail;
    });
  }

  void _selectEntry(ArrLibraryEntry entry) {
    setState(() {
      _selected = entry;
      _episodes = const [];
      _releaseSearched = false;
      _releases = const [];
      _releasesError = null;
      _grabStatuses.clear();
    });
    if (entry.isMovie) {
      final movie = entry.movie!;
      _searchReleases(
        label:
            movie.year != null ? '${movie.title} (${movie.year})' : movie.title,
        run: () => ref.read(radarrClientProvider)!.releasesForMovie(movie.id),
      );
    } else {
      _loadEpisodes(entry.series!);
    }
  }

  void _backToLibrary() {
    setState(() {
      _selected = null;
      _episodes = const [];
      _releaseSearched = false;
      _releases = const [];
      _releasesError = null;
      _grabStatuses.clear();
    });
  }

  void _backToPicker() {
    setState(() {
      _releaseSearched = false;
      _releases = const [];
      _releasesError = null;
      _grabStatuses.clear();
    });
  }

  Future<void> _loadEpisodes(ArrSeries series) async {
    setState(() => _episodesLoading = true);
    final sonarr = ref.read(sonarrClientProvider);
    final result = sonarr == null
        ? const ArrFailure<List<ArrEpisode>>(ArrApiError.unreachable)
        : await sonarr.episodesForSeries(series.id);
    if (!mounted) return;
    setState(() {
      _episodesLoading = false;
      _episodes = switch (result) {
        ArrSuccess(:final data) => data,
        ArrFailure() => const [],
      };
    });
  }

  void _searchSeason(int seasonNumber) {
    final series = _selected!.series!;
    _searchReleases(
      label: '${series.title} — Saison $seasonNumber',
      run: () => ref
          .read(sonarrClientProvider)!
          .releasesForSeason(series.id, seasonNumber),
    );
  }

  void _searchEpisode(ArrEpisode episode) {
    final series = _selected!.series!;
    _searchReleases(
      label:
          '${series.title} — S${episode.seasonNumber}E${episode.episodeNumber}',
      run: () => ref.read(sonarrClientProvider)!.releasesForEpisode(episode.id),
    );
  }

  /// Point d'entrée commun film / saison / épisode — la recherche
  /// interactive peut prendre jusqu'à 30s (les indexeurs sont interrogés
  /// en direct), d'où l'état de chargement dédié plutôt qu'un spinner
  /// générique de page.
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
    final client = _selected!.isMovie
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
    FladderSnack.show(message, context: context);
  }

  String _errorMessage(ArrApiError error, String? detail) {
    final base = switch (error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound => "Route introuvable.",
      ArrApiError.serverError => "Erreur de l'indexeur ou du serveur.",
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return detail == null ? base : '$base $detail';
  }

  @override
  Widget build(BuildContext context) {
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;
    return ArrDesktopScope(
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: sideBarInset),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Recherche interactive',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: AppSpacing.md),
                    _ArrSearchField(
                        controller: _queryController,
                        onChanged: _onQueryChanged),
                    const SizedBox(height: AppSpacing.lg),
                    if (_selected == null)
                      _buildLibrarySection(context)
                    else
                      _buildSelectionSection(context),
                  ],
                ),
              ),
              PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                start: AppSpacing.sm,
                child: FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () => context.router.popBack(),
                  child: ExcludeFocus(
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.scrim.withValues(alpha: 0.4),
                        foregroundColor: AppColors.textPrimary,
                      ),
                      onPressed: () => context.router.popBack(),
                      icon: const BackButtonIcon(),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                end: AppSpacing.sm,
                child: FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () =>
                      context.router.push(const ArrSettingsRoute()),
                  child: ExcludeFocus(
                    child: Tooltip(
                      message: 'Réglages Radarr / Sonarr',
                      child: IconButton(
                        onPressed: () =>
                            context.router.push(const ArrSettingsRoute()),
                        icon: const Icon(Icons.settings_outlined),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrarySection(BuildContext context) {
    if (!_librarySearched) {
      if (_libraryLoading) {
        return const _ArrLoadingState(label: 'Recherche…');
      }
      return const _ArrHintState(
          label:
              'Tapez un titre pour chercher dans la bibliothèque Radarr/Sonarr.');
    }
    if (_libraryLoading) {
      return const _ArrLoadingState(label: 'Recherche…');
    }
    if (_libraryError != null) {
      return _ArrErrorState(
          message: _errorMessage(_libraryError!, _libraryErrorDetail));
    }
    if (_libraryResults.isEmpty) {
      return const _ArrHintState(label: 'Aucun résultat.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in _libraryResults)
          _ArrLibraryResultRow(
            entry: entry,
            onSelect: () => _selectEntry(entry),
          ),
      ],
    );
  }

  Widget _buildSelectionSection(BuildContext context) {
    final selected = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrBackRow(
          label: selected.title,
          onBack: _backToLibrary,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!selected.isMovie && !_releaseSearched) ...[
          if (_episodesLoading)
            const _ArrLoadingState(label: 'Chargement des épisodes…')
          else if (_episodes.isEmpty)
            const _ArrHintState(label: 'Aucun épisode trouvé pour cette série.')
          else
            ArrSeasonEpisodePicker(
              episodes: _episodes,
              onSearchSeason: _searchSeason,
              onSearchEpisode: _searchEpisode,
            ),
        ] else
          _buildReleaseSection(context),
      ],
    );
  }

  Widget _buildReleaseSection(BuildContext context) {
    final selected = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!selected.isMovie)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ArrBackRow(
              label: _releaseSearchLabel ?? selected.title,
              onBack: _backToPicker,
              backLabel: 'Changer de saison/épisode',
            ),
          ),
        if (_releasesLoading)
          const _ArrLoadingState(
              label: 'Recherche auprès des indexeurs (jusqu\'à 30 secondes)…')
        else if (_releasesError != null)
          _ArrErrorState(
              message: _errorMessage(_releasesError!, _releasesErrorDetail))
        else if (_releases.isEmpty)
          const _ArrHintState(label: 'Aucun résultat.')
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

/// Une ligne de résultat bibliothèque — vignette à gauche (jaquette Primary
/// Radarr/Sonarr), puis titre/année/statut/qualité/saisons. Jamais une
/// simple ligne de texte : le poster est ce qui permet de distinguer deux
/// titres homonymes ou une simple faute de frappe au premier coup d'œil.
class _ArrLibraryResultRow extends StatelessWidget {
  final ArrLibraryEntry entry;
  final VoidCallback onSelect;

  const _ArrLibraryResultRow({required this.entry, required this.onSelect});

  static const _posterWidth = 40.0;
  static const _posterHeight = 60.0;

  Color _statusColor() {
    if (!entry.monitored) return AppColors.textDisabled;
    if (entry.isComplete) return AppColors.success;
    if (entry.hasContent) return AppColors.textSecondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textSecondary);

    final details = <String>[
      entry.statusLabel,
      if (entry.qualityName != null) entry.qualityName!,
      if (entry.seasonCount != null)
        '${entry.seasonCount} saison${entry.seasonCount! > 1 ? 's' : ''}',
    ];

    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: onSelect,
      child: ExcludeFocus(
        child: InkWell(
          borderRadius: AppRadii.controlBorder,
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: AppRadii.controlBorder,
                  child: SizedBox(
                    width: _posterWidth,
                    height: _posterHeight,
                    child: entry.posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: entry.posterUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                _ArrPosterFallback(isMovie: entry.isMovie),
                            placeholder: (context, url) =>
                                const ColoredBox(color: AppColors.surfaceHigh),
                          )
                        : _ArrPosterFallback(isMovie: entry.isMovie),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (entry.year != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text('(${entry.year})', style: subtitleStyle),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 7, color: _statusColor()),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              details.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: subtitleStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrPosterFallback extends StatelessWidget {
  final bool isMovie;
  const _ArrPosterFallback({required this.isMovie});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceHigh,
      child: Center(
        child: Icon(
          isMovie ? Icons.movie_outlined : Icons.tv_outlined,
          size: 18,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _ArrSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ArrSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textPrimary),
      cursorColor: AppColors.textPrimary,
      decoration: const InputDecoration(
        hintText: 'Chercher un film ou une série…',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.focus),
        ),
      ),
    );
  }
}

class _ArrBackRow extends StatelessWidget {
  final String label;
  final VoidCallback onBack;
  final String backLabel;

  const _ArrBackRow(
      {required this.label, required this.onBack, this.backLabel = 'Retour'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onBack,
          child: ExcludeFocus(
            child: Tooltip(
              message: backLabel,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

class _ArrLoadingState extends StatelessWidget {
  final String label;
  const _ArrLoadingState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
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

class _ArrHintState extends StatelessWidget {
  final String label;
  const _ArrHintState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _ArrErrorState extends StatelessWidget {
  final String message;
  const _ArrErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
