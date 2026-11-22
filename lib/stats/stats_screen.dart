import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/letterboxd_import_dialog.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/ratings/kinos_rating_button.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/screens/shared/user_icon.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/palette_service.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

import 'viewing_backfill.dart';
import 'viewing_log.dart';
import 'viewing_recorder.dart';
import 'viewing_stats.dart';

/// Toutes les séances du journal du profil actif.
final viewingEventsProvider =
    FutureProvider.autoDispose<List<ViewingEvent>>((ref) async {
  final store = ref.watch(viewingLogStoreProvider);
  if (store == null) return const <ViewingEvent>[];
  return store.all();
});

/// Les fiches Jellyfin des mieux notés, pour leurs affiches.
final _statsItemsProvider = FutureProvider.autoDispose
    .family<List<ItemBaseModel>, String>((ref, ids) async {
  if (ids.isEmpty) return const [];
  final response = await ref
      .read(jellyApiProvider)
      .usersUserIdItemsGet(ids: ids.split(','), enableUserData: true);
  return [
    for (final dto in response.body?.items ?? const <BaseItemDto>[])
      ItemBaseModel.fromBaseDto(dto, ref)
  ];
});

/// Les affiches TMDB (par Seerr) des mieux notés absents de la
/// bibliothèque : « 1,2,3 » → id TMDB → URL.
final _statsRequestPostersProvider = FutureProvider.autoDispose
    .family<Map<int, String>, String>((ref, ids) async {
  if (ids.isEmpty) return const {};
  final api = ref.read(seerrApiProvider);
  final posters = <int, String>{};
  await Future.wait([
    for (final id in ids.split(',').map(int.parse))
      api.movieDetails(tmdbId: id).then((response) {
        final path = response.body?.internalPosterPath;
        if (path != null && path.isNotEmpty) {
          posters[id] = 'https://image.tmdb.org/t/p/w500$path';
        }
      }).catchError((_) {}),
  ]);
  return posters;
});

/// La teinte du film à l'affiche, extraite de son image de fond.
final _bannerPaletteProvider = FutureProvider.autoDispose
    .family<HeroPalette, ({String id, ImageProvider image})>((ref, key) => ref
        .read(paletteServiceProvider)
        .forItem(itemId: key.id, image: key.image));

/// « 412 h », « 35 min ».
String formatHours(int seconds) {
  final hours = seconds ~/ 3600;
  if (hours >= 1) return '${NumberFormat.decimalPattern('fr').format(hours)} h';
  return '${seconds ~/ 60} min';
}

/// Vos statistiques : par année, par mois ou depuis toujours, d'après le
/// journal de visionnage (Kinos, Letterboxd, Jellyfin) et vos notes.
@RoutePage()
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod(year: DateTime.now().year);
  bool _rebuilding = false;

  /// Le journal vide à l'ouverture est relu une fois : un import ou un
  /// historique Jellyfin d'avant la page ne l'a jamais rempli.
  bool _autoRebuilt = false;

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    await ref.read(viewingBackfillProvider).rebuild();
    ref.invalidate(viewingEventsProvider);
    if (mounted) setState(() => _rebuilding = false);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(viewingEventsProvider).valueOrNull;
    final ratings = ref.watch(kinosRatingsProvider);
    final user = ref.watch(userProvider);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    if (events != null && events.isEmpty && !_autoRebuilt) {
      _autoRebuilt = true;
      _rebuilding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuild();
      });
    }
    final stats =
        events == null ? null : computeStats(events, ratings, _period);
    final years = {...?stats?.years, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    Widget section(String title, {String? detail, required Widget child}) =>
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: title, style: text.headlineMedium),
              if (detail != null)
                TextSpan(
                    text: '  $detail',
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
            ])),
            const SizedBox(height: AppSpacing.sm),
            child,
          ]),
        );

    final topRated = stats?.topRated ?? const [];
    final ids = [
      for (final t in topRated)
        if (t.event.jellyfinId case final id?) id
    ];
    // Le bandeau : le mieux noté de la période qui est dans la
    // bibliothèque, sinon le plus revu, sinon le plus long.
    final bannerEvent = [
      for (final t in topRated) t.event,
      if (stats?.mostSeen case final seen?) seen.event,
      if (stats?.longestFilm case final film?) film,
    ].where((e) => e.jellyfinId != null).firstOrNull;
    if (bannerEvent != null && !ids.contains(bannerEvent.jellyfinId)) {
      ids.add(bannerEvent.jellyfinId!);
    }
    final posters =
        ref.watch(_statsItemsProvider(ids.join(','))).valueOrNull ?? const [];
    final bannerItem =
        posters.where((p) => p.id == bannerEvent?.jellyfinId).firstOrNull;
    final bannerImage = bannerItem?.images?.backDrop?.firstOrNull;
    final bannerRating = [
      for (final t in topRated)
        if (t.event.jellyfinId == bannerItem?.id) t.rating
    ].firstOrNull;
    final tint = bannerItem == null || bannerImage == null
        ? AppColors.heroFallback
        : ref
                .watch(_bannerPaletteProvider(
                    (id: bannerItem.id, image: bannerImage.imageProvider)))
                .valueOrNull
                ?.tint ??
            AppColors.heroFallback;
    final onImage = bannerImage != null;
    // L'en-tête : votre photo, votre nom, et le film à l'affiche.
    final header = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: SizedBox.square(
            dimension: AppStatsLayout.portraitSize,
            child: UserIcon(user: user, cornerRadius: AppRadii.card)),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Vos statistiques',
                  style: text.bodySmall?.copyWith(
                      color: onImage
                          ? AppColors.textPrimary.withValues(alpha: .75)
                          : AppColors.textSecondary)),
              Text(user?.name ?? '',
                  style: text.displaySmall
                      ?.copyWith(color: AppColors.textPrimary)),
            ]),
      ),
      if (bannerItem != null && bannerRating != null)
        Flexible(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    _period.year == null
                        ? 'Votre mieux noté'
                        : 'Votre mieux noté de ${_period.year}',
                    style: text.bodySmall?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: .75))),
                Text('${bannerItem.name} · ${formatStars(bannerRating)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium
                        ?.copyWith(color: AppColors.textPrimary)),
              ]),
        ),
    ]);

    final body = <Widget>[
      Wrap(spacing: AppSpacing.xxs, runSpacing: AppSpacing.xxs, children: [
        for (final year in years)
          _Chip('$year',
              selected: _period.year == year,
              onTap: () => setState(() => _period = StatsPeriod(year: year))),
        _Chip('Depuis toujours',
            selected: _period.year == null,
            onTap: () => setState(() => _period = const StatsPeriod())),
      ]),
      if (_period.year != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.xxs, runSpacing: AppSpacing.xxs, children: [
          _Chip('Toute l\'année',
              selected: _period.month == null,
              onTap: () =>
                  setState(() => _period = StatsPeriod(year: _period.year))),
          for (var m = 1; m <= 12; m++)
            _Chip(
                toBeginningOfSentenceCase(
                    DateFormat('MMM', locale).format(DateTime(2000, m))),
                selected: _period.month == m,
                onTap: () => setState(
                    () => _period = StatsPeriod(year: _period.year, month: m))),
        ]),
      ],
      if (stats == null || (stats.isEmpty && _rebuilding))
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (stats.isEmpty)
        _Empty(
            rebuilding: _rebuilding,
            onRebuild: _rebuild,
            onImport: () => showLetterboxdImportDialog(context))
      else ...[
        const SizedBox(height: AppSpacing.xl),
        _Numbers(stats: stats),
        section('Activité',
            detail: _period.year == null
                ? 'heures devant l\'écran, année par année'
                : _period.month == null
                    ? 'heures devant l\'écran, mois par mois'
                    : 'heures devant l\'écran, jour par jour',
            child: _Bars(
                values: stats.buckets,
                height: AppStatsLayout.barsHeight,
                highlight: stats.busiestBucket,
                valueLabel: formatHours,
                tooltip: (i) {
                  final hours = formatHours(stats.buckets[i]);
                  return _period.year == null
                      ? '${stats.years.last + i} · $hours'
                      : _period.month == null
                          ? '${toBeginningOfSentenceCase(DateFormat('MMMM y', locale).format(DateTime(_period.year!, i + 1)))} · $hours'
                          : '${DateFormat('EEEE d MMMM', locale).format(DateTime(_period.year!, _period.month!, i + 1))} · $hours';
                },
                labels: [
                  for (var i = 0; i < stats.buckets.length; i++)
                    _period.year == null
                        ? '${stats.years.last + i}'
                        : _period.month == null
                            ? toBeginningOfSentenceCase(
                                DateFormat('MMM', locale)
                                    .format(DateTime(2000, i + 1)))
                            : (i + 1) % 5 == 0 || i == 0
                                ? '${i + 1}'
                                : '',
                ])),
        if (_period.year != null && _period.month == null)
          section('Jour par jour',
              detail: 'une case par jour, plus claire quand vous avez '
                  'regardé davantage',
              child: _Calendar(year: _period.year!, days: stats.days)),
        LayoutBuilder(builder: (context, constraints) {
          final left =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (stats.genres.isNotEmpty)
              section('Genres', child: _Ranking(stats.genres)),
            if (stats.directors.isNotEmpty)
              section('Réalisateurs', child: _Ranking(stats.directors)),
          ]);
          final right =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (stats.average != null)
              section('Vos notes',
                  detail:
                      'moyenne ${stats.average!.toStringAsFixed(1).replaceAll('.', ',')}',
                  child: _Bars(
                      values: stats.ratings,
                      height: AppStatsLayout.ratingBarsHeight,
                      valueLabel: (count) => '$count',
                      tooltip: (i) =>
                          '${formatStars(i + 1)} · ${stats.ratings[i]} '
                          '${stats.ratings[i] > 1 ? 'films' : 'film'}',
                      labels: const [
                        '½',
                        '1',
                        '',
                        '2',
                        '',
                        '3',
                        '',
                        '4',
                        '',
                        '5'
                      ])),
            if (stats.actors.isNotEmpty)
              section('Acteurs', child: _Ranking(stats.actors)),
          ]);
          if (constraints.maxWidth < AppStatsLayout.twoColumnsMinWidth) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: right),
          ]);
        }),
        section('Records', child: _Records(stats: stats, locale: locale)),
        section(
          'Votre Wrapped ${_period.year ?? DateTime.now().year}',
          detail: 'l\'année en quelques diapos, à partager en story · '
              'disponible en décembre',
          child: const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Text(
              'Les heures sont exactes pour ce que vous regardez dans Kinos ; '
              'pour Letterboxd et l\'historique Jellyfin, la durée du titre '
              'compte quand il a été vu en entier.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    ];

    final byId = {for (final p in posters) p.id: p};
    // Hors bibliothèque (vus au cinéma, ailleurs) : l'affiche TMDB par
    // Seerr, et la fiche Seerr au clic.
    final canRequest = ref.watch(
        userProvider.select((u) => u?.seerrCredentials?.isConfigured ?? false));
    final elsewhere = [
      for (final t in topRated)
        if (!byId.containsKey(t.event.jellyfinId) && t.event.tmdbId != null)
          t.event.tmdbId!
    ];
    final requestPosters = canRequest
        ? ref
                .watch(_statsRequestPostersProvider(elsewhere.join(',')))
                .valueOrNull ??
            const <int, String>{}
        : const <int, String>{};
    final tiles = [
      for (final t in topRated)
        if (byId[t.event.jellyfinId] case final item?)
          RecommendationTile(
            identity: ('stats', item.id),
            previewImage: item.getPosters?.primary,
            title: item.name,
            subtitle: formatStars(t.rating),
            buildPoster: RecommendationTile.jellyfin(item: item).buildPoster,
            navigate: RecommendationTile.jellyfin(item: item).navigate,
          )
        else if (canRequest && t.event.tmdbId != null)
          (() {
            final request = RecommendationTile.request(
                tmdbId: t.event.tmdbId!,
                title: t.event.title,
                year: t.event.year,
                posterUrl: requestPosters[t.event.tmdbId]);
            return RecommendationTile(
              identity: ('stats', 'tmdb', t.event.tmdbId),
              previewImage: request.previewImage,
              title: t.event.title,
              subtitle: formatStars(t.rating),
              buildPoster: request.buildPoster,
              navigate: request.navigate,
            );
          })(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            // La teinte du film à l'affiche, résorbée sous les chiffres.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: AppStatsLayout.bannerHeight + AppStatsLayout.tintTail,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.heroTint,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [
                      0,
                      AppStatsLayout.bannerHeight /
                          (AppStatsLayout.bannerHeight +
                              AppStatsLayout.tintTail),
                      1
                    ],
                        colors: [
                      tint,
                      tint,
                      AppColors.background
                    ])),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Banner(image: bannerImage, padding: padding, child: header),
              Padding(
                padding: padding.copyWith(top: AppSpacing.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body),
              ),
            ]),
          ]),
        ),
        if (tiles.isNotEmpty) ...[
          SliverPadding(
            padding:
                padding.copyWith(top: AppSpacing.xl, bottom: AppSpacing.sm),
            sliver: SliverToBoxAdapter(
                child: Text(
                    _period.year == null
                        ? 'Vos mieux notés'
                        : 'Vos mieux notés de ${_period.year}',
                    style: text.headlineMedium)),
          ),
          RecommendationTileGrid(tiles: tiles, contentPadding: padding),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
      ]),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.stats});
  final ViewingStats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget number(String value, String label) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: text.displayMedium
                      ?.copyWith(color: AppColors.textPrimary)),
              Text(label,
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]);
    return Wrap(spacing: AppSpacing.xxl, runSpacing: AppSpacing.lg, children: [
      number('${stats.films}', stats.films > 1 ? 'films' : 'film'),
      number(formatHours(stats.seconds), 'devant l\'écran'),
      number('${stats.episodes}',
          'épisodes · ${stats.series} ${stats.series > 1 ? 'séries' : 'série'}'),
      if (stats.elsewhere > 0)
        number('${stats.elsewhere}', 'vus ailleurs (cinéma…)'),
    ]);
  }
}

/// Un histogramme : une barre par valeur, la plus haute à pleine hauteur,
/// sa valeur au-dessus ([values] lisibles via [valueLabel]) et le détail au
/// survol ([tooltip]). La mise en avant [highlight] est plus claire.
class _Bars extends StatelessWidget {
  const _Bars(
      {required this.values,
      required this.height,
      required this.labels,
      this.valueLabel,
      this.tooltip,
      this.highlight});
  final List<int> values;
  final double height;
  final List<String> labels;
  final String Function(int value)? valueLabel;
  final String Function(int index)? tooltip;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final top = values.fold(0, (a, b) => a > b ? a : b);
    final meta = AppTypography.meta.copyWith(color: AppColors.textSecondary);
    return Column(children: [
      SizedBox(
        height:
            height + (valueLabel == null ? 0 : AppStatsLayout.labelRowHeight),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Tooltip(
                message: tooltip?.call(i) ?? '',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStatsLayout.dayGap),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (valueLabel != null)
                          SizedBox(
                            height: AppStatsLayout.labelRowHeight,
                            child: values[i] == 0
                                ? null
                                : Text(valueLabel!(values[i]),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: meta.copyWith(
                                        color: i == highlight
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary)),
                          ),
                        SizedBox(
                          height: top == 0
                              ? 0
                              : height * (values[i] / top).clamp(.02, 1),
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(
                                    alpha: i == highlight ? 1 : .55),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppSpacing.xxs))),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Row(children: [
        for (final label in labels)
          Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: meta)),
      ]),
    ]);
  }
}

/// Le calendrier de l'année : une case par jour, en colonnes de semaines
/// (lundi en haut), plus claire quand on a regardé davantage, les mois
/// au-dessus et une légende en dessous.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.year, required this.days});
  final int year;
  final Map<DateTime, int> days;

  /// Le jour [offset] après [from], en jours du calendrier : une Duration
  /// de 24 h glisse d'une heure aux changements d'heure et ne retombe plus
  /// sur minuit, la clé des jours.
  static DateTime _day(DateTime from, int offset) =>
      DateTime(from.year, from.month, from.day + offset);

  static double _alpha(int seconds, int top) =>
      seconds == 0 || top == 0 ? .06 : .2 + .75 * (seconds / top);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year);
    final start = _day(first, -(first.weekday - 1));
    final weeks =
        (DateTime(year + 1).difference(start).inHours / 24 / 7).ceil();
    final top = days.values.fold(0, (a, b) => a > b ? a : b);
    final meta = AppTypography.meta.copyWith(color: AppColors.textSecondary);
    const gap = AppStatsLayout.dayGap;
    return LayoutBuilder(builder: (context, constraints) {
      final size = ((constraints.maxWidth - gap * (weeks - 1)) / weeks)
          .clamp(2.0, AppStatsLayout.dayMaxSize);
      final width = weeks * size + (weeks - 1) * gap;
      Widget cell(double alpha) => SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(size / 5),
              ),
            ),
          );
      return SizedBox(
        width: width,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Les mois, au-dessus de la semaine qui contient leur 1er.
              SizedBox(
                height: AppStatsLayout.labelRowHeight,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (var m = 1; m <= 12; m++)
                    Positioned(
                      left: (DateTime(year, m).difference(start).inHours ~/
                              24 ~/
                              7) *
                          (size + gap),
                      child: Text(
                          toBeginningOfSentenceCase(DateFormat('MMM', 'fr')
                              .format(DateTime(year, m))),
                          style: meta),
                    ),
                ]),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Padding(
                        padding:
                            EdgeInsets.only(right: w == weeks - 1 ? 0 : gap),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          for (var d = 0; d < 7; d++)
                            Builder(builder: (context) {
                              final day = _day(start, w * 7 + d);
                              final seconds = days[day] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: gap),
                                child: day.year != year
                                    ? SizedBox.square(dimension: size)
                                    : Tooltip(
                                        message:
                                            '${DateFormat('EEEE d MMMM', 'fr').format(day)}'
                                            '${seconds > 0 ? ' · ${formatHours(seconds)}' : ''}',
                                        child: cell(_alpha(seconds, top)),
                                      ),
                              );
                            }),
                        ]),
                      ),
                  ]),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Moins', style: meta),
                  const SizedBox(width: AppSpacing.xs),
                  for (final a in [.06, .2, .45, .7, .95]) ...[
                    cell(a),
                    const SizedBox(width: gap),
                  ],
                  const SizedBox(width: AppSpacing.xs - gap),
                  Text('Plus', style: meta),
                ]),
              ),
            ]),
      );
    });
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking(this.items);
  final List<Ranked> items;

  @override
  Widget build(BuildContext context) {
    final top = items.isEmpty ? 1 : items.first.count;
    final text = Theme.of(context).textTheme;
    return Column(children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(children: [
            SizedBox(
                width: AppStatsLayout.rankNameWidth,
                child: Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textPrimary))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: item.count / top,
                  child: Container(
                      height: AppStatsLayout.rankBarHeight,
                      decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(
                              AppStatsLayout.rankBarHeight / 2))),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('${item.count}',
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ]),
        ),
    ]);
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.stats, required this.locale});
  final ViewingStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final night = stats.longestNight;
    final film = stats.longestFilm;
    final seen = stats.mostSeen;
    final cards = [
      if (night != null)
        (
          'Plus longue soirée',
          '${night.episodes} épisodes · ${DateFormat('d MMMM y', locale).format(night.day)}'
        ),
      if (film != null)
        (
          'Plus long film',
          '${film.title} · ${formatHours(film.runtimeSeconds ?? 0)}'
        ),
      if (seen != null)
        ('Le plus revu', '${seen.event.title} · ${seen.times} fois'),
    ];
    if (cards.isEmpty) {
      return Text('Pas encore de record.',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary));
    }
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
      for (final (label, value) in cards)
        DecoratedBox(
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadii.cardBorder),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(value,
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textPrimary)),
                ]),
          ),
        ),
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.rebuilding,
      required this.onRebuild,
      required this.onImport});
  final bool rebuilding;
  final VoidCallback onRebuild;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rien sur cette période.', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
            'Chaque film lu dans Kinos est noté ici. Pour le passé, importez '
            'votre historique Letterboxd, ou relisez celui de Jellyfin.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.xs, children: [
          _Chip('Importer depuis Letterboxd', selected: false, onTap: onImport),
          _Chip(
              rebuilding ? 'Lecture de l\'historique…' : 'Relire l\'historique',
              selected: false,
              onTap: rebuilding ? () {} : onRebuild),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              border: Border.all(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.borderStrong),
              borderRadius: AppRadii.controlBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              child: Text(label,
                  style: AppTypography.meta.copyWith(
                      color: selected
                          ? AppColors.background
                          : AppColors.textPrimary)),
            ),
          ),
        ),
      );
}

/// Le bandeau : l'image de fond du film à l'affiche, qui se dissout dans
/// sa teinte (peinte derrière par la page), l'en-tête posé en bas. Sans
/// image, l'en-tête seul sur la teinte de repli.
class _Banner extends StatelessWidget {
  const _Banner(
      {required this.image, required this.padding, required this.child});
  final ImageData? image;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (image == null) {
      return Padding(
        padding: padding.copyWith(
            top: top + AppTopNavigation.contentInset + AppSpacing.lg),
        child: child,
      );
    }
    return SizedBox(
      height: AppStatsLayout.bannerHeight,
      child: ClipRect(
          child: Stack(fit: StackFit.expand, children: [
        // Le calque masqué dépasse sous le bandeau, coupé par le ClipRect :
        // le bord fractionnaire du ShaderMask laisserait sinon une ligne
        // sombre au défilement (cf. HomeHeroBackdrop).
        Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -AppHeroLayout.seamGuard,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, AppStatsLayout.bannerFadeStart, 1],
                colors: [Colors.white, Colors.white, Colors.transparent],
              ).createShader(rect),
              child: Stack(fit: StackFit.expand, children: [
                KinosImage(
                    key: ValueKey(image!.key),
                    image: image,
                    alignment: AppHeroLayout.imageAlignment,
                    disableBlur: true),
                // Le voile de lecture, sous l'en-tête.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, .6],
                      colors: [
                        AppColors.scrim.withValues(alpha: .85),
                        AppColors.scrim.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ]),
            )),
        Positioned(
          left: padding.left,
          right: padding.right,
          bottom: AppSpacing.lg,
          child: child,
        ),
      ])),
    );
  }
}
