import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/scroll_pinned_back_button.dart';

import '../upcoming_models.dart';
import '../upcoming_providers.dart';
import '../upcoming_screen.dart' show openUpcoming, upcomingTile;
import '../upcoming_strings.dart';
import 'entity_models.dart';
import 'entity_providers.dart';

/// La page d'une personne, d'un studio, d'une chaîne ou d'une saga : ce qui
/// arrive, ce qui est déjà dans la bibliothèque, le reste à demander, et
/// le bouton pour la suivre.
@RoutePage()
class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen(
      {@PathParam('kind') required this.kind,
      @PathParam('id') required this.id,
      this.name,
      super.key});

  /// Nom d'un [UpcomingFollowKind] : `person`, `company`, `network`,
  /// `collection`.
  final String kind;
  final int id;

  /// Affiché en attendant la fiche.
  final String? name;

  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  UpcomingRole? _role;

  UpcomingFollowKind get _kind =>
      UpcomingFollowKind.values.asNameMap()[widget.kind] ??
      UpcomingFollowKind.person;

  EntityKey get _key => (kind: _kind, id: widget.id);

  UpcomingRole _roleFor(EntityState state) =>
      _role ??
      (state.header?.knownFor == 'Directing' && state.directing.isNotEmpty ||
              state.acting.isEmpty
          ? UpcomingRole.directing
          : UpcomingRole.acting);

  UpcomingFollow? _follow(EntityState state) {
    final header = state.header;
    if (header == null) return null;
    return UpcomingFollow(
        kind: _kind,
        id: widget.id,
        name: header.name,
        image: header.image,
        role: _kind == UpcomingFollowKind.person ? _roleFor(state) : null);
  }

  void _toggleFollow() {
    final follow = _follow(ref.read(entityProvider(_key)));
    if (follow != null && ref.read(upcomingAvailableProvider)) {
      ref.read(upcomingProvider.notifier).toggleFollow(follow);
    }
  }

  void _cycleRole() {
    final state = ref.read(entityProvider(_key));
    if (state.acting.isEmpty || state.directing.isEmpty) return;
    setState(() => _role = _roleFor(state) == UpcomingRole.acting
        ? UpcomingRole.directing
        : UpcomingRole.acting);
  }

  void _cycleSort() {
    final state = ref.read(entityProvider(_key));
    ref.read(entityProvider(_key).notifier).setSort(
        EntitySort.values[(state.sort.index + 1) % EntitySort.values.length]);
  }

  static int _byPosterThenDate(EntityTitle a, EntityTitle b) {
    if ((a.posterPath == null) != (b.posterPath == null)) {
      return a.posterPath == null ? 1 : -1;
    }
    final da = a.date, db = b.date;
    if (da == null || db == null) {
      return da == db ? 0 : (da == null ? 1 : -1);
    }
    return da.compareTo(db);
  }

  static String _subtitle(EntityTitle t, {bool role = false}) => [
        if (!t.isMovie) EntityStrings.series,
        if (t.date != null) '${t.date!.year}' else EntityStrings.announced,
        if (role && t.character != null) t.character!,
        if (!t.isMovie && t.episodes != null && t.episodes! > 0)
          '${t.episodes} ${EntityStrings.episodes}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entityProvider(_key));
    final locale = Localizations.localeOf(context).toString();
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final text = Theme.of(context).textTheme;
    final today = DateTime.now();
    final person = _kind == UpcomingFollowKind.person;
    final role = _roleFor(state);
    final acting = person && role == UpcomingRole.acting;

    // Les titres de la page, puis leur répartition en sections.
    final titles = switch (_kind) {
      UpcomingFollowKind.person => acting ? state.acting : state.directing,
      _ => state.catalogue,
    };
    final main = [
      for (final t in titles)
        if (!acting || state.isMain(t)) t
    ];
    final appearances = acting
        ? [
            for (final t in titles)
              if (!state.isMain(t)) t
          ]
        : const <EntityTitle>[];
    // À venir : ceux qui ont déjà une affiche d'abord (les projets à peine
    // annoncés n'en ont pas), puis du plus proche au plus lointain.
    final upcoming = [
      ...(person || _kind == UpcomingFollowKind.collection
          ? [
              for (final t in main)
                if (t.upcoming(today)) t
            ]
          : state.upcoming)
    ]..sort(_byPosterThenDate);
    final released = [
      for (final t in main)
        if (person || _kind == UpcomingFollowKind.collection
            ? !t.upcoming(today)
            : true)
          t
    ];
    // Studio, chaîne : la bibliothèque vient de Jellyfin (tout ce qu'il
    // range sous ce nom), pas des seules pages de catalogue chargées.
    final owner = _kind == UpcomingFollowKind.company ||
        _kind == UpcomingFollowKind.network;
    final header = state.header;
    final jellyfin = owner && header != null && header.name.isNotEmpty
        ? ref
            .watch(entityLibraryProvider((
              name: header.name,
              series: _kind == UpcomingFollowKind.network
            )))
            .valueOrNull
        : null;
    final owned = {
      for (final item in jellyfin ?? const <ItemBaseModel>[])
        if (item.overview.tmdbId case final id?) id
    };
    final library = jellyfin != null
        ? const <EntityTitle>[]
        : [
            for (final t in released)
              if (t.inLibrary) t
          ];
    final rest = [
      for (final t in released)
        if (!t.inLibrary && !owned.contains('${t.id}')) t
    ];

    Widget heading(String title, [String? detail]) => SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl, bottom: AppSpacing.sm),
          sliver: SliverToBoxAdapter(
              child: Text.rich(TextSpan(children: [
            TextSpan(text: title, style: text.headlineMedium),
            if (detail != null)
              TextSpan(
                  text: '  $detail',
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ]))),
        );

    Widget grid(List<EntityTitle> titles,
            {bool pill = false, bool label = true}) =>
        RecommendationTileGrid(tiles: [
          for (final t in titles)
            upcomingTile(t.toEntry(), locale,
                subtitle: _subtitle(t, role: acting), pill: pill, label: label)
        ], contentPadding: padding);

    final follow = _follow(state);
    final available = ref.watch(upcomingAvailableProvider);
    final followed = follow != null &&
        ref.watch(upcomingProvider.select((s) => s.isFollowed(follow.key)));

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _EntityBanner(
          kind: _kind,
          header: state.header,
          fallbackName: widget.name ?? '',
          padding: padding,
          // Stable pendant le tri des rôles : seules les apparitions
          // évidentes (propre rôle, voix) sont écartées.
          posters: <String>{
            for (final t in [
              ...state.acting,
              ...state.directing
            ]..sort((a, b) => b.popularity.compareTo(a.popularity)))
              if (t.posterPath != null && !isAppearance(t)) t.posterPath!
          }.take(40).toList(),
          follow: available && follow != null
              ? _FollowButton(
                  label: switch ((_kind, role, followed)) {
                    (
                      UpcomingFollowKind.person,
                      UpcomingRole.directing,
                      false
                    ) =>
                      EntityStrings.followDirecting,
                    (UpcomingFollowKind.person, UpcomingRole.directing, true) =>
                      EntityStrings.followedDirecting,
                    (UpcomingFollowKind.person, _, false) =>
                      EntityStrings.followActing,
                    (UpcomingFollowKind.person, _, true) =>
                      EntityStrings.followedActing,
                    (UpcomingFollowKind.collection, _, false) =>
                      EntityStrings.followSaga,
                    (UpcomingFollowKind.collection, _, true) =>
                      EntityStrings.followedSaga,
                    (_, _, false) => EntityStrings.follow,
                    (_, _, true) => EntityStrings.followed,
                  },
                  followed: followed,
                  onTap: _toggleFollow)
              : null,
        ),
      ),
      SliverPadding(
        padding: padding.copyWith(top: AppSpacing.md),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (person &&
                  state.acting.isNotEmpty &&
                  state.directing.isNotEmpty) ...[
                _Chip('${EntityStrings.acting} · ${state.acting.length}',
                    selected: acting,
                    onTap: () => setState(() => _role = UpcomingRole.acting)),
                _Chip('${EntityStrings.directing} · ${state.directing.length}',
                    selected: !acting,
                    onTap: () =>
                        setState(() => _role = UpcomingRole.directing)),
                const SizedBox(width: AppSpacing.md),
              ],
              if (!person && _kind != UpcomingFollowKind.collection) ...[
                for (final (sort, label) in [
                  (EntitySort.recent, EntityStrings.recent),
                  (EntitySort.rated, EntityStrings.rated),
                  (EntitySort.popular, EntityStrings.popular),
                ])
                  _Chip(label,
                      selected: state.sort == sort,
                      onTap: () => ref
                          .read(entityProvider(_key).notifier)
                          .setSort(sort)),
                const SizedBox(width: AppSpacing.md),
              ],
              if (state.checking > 0)
                Text(EntityStrings.checking(state.checking),
                    style: AppTypography.meta
                        .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      if (state.loading)
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          sliver: SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
        )
      else if (state.failed)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Text(EntityStrings.failed,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        )
      else ...[
        if (upcoming.isNotEmpty) ...[
          heading(EntityStrings.upcoming, '${upcoming.length}'),
          grid(upcoming, pill: true),
        ],
        if (jellyfin != null && jellyfin.isNotEmpty) ...[
          heading(EntityStrings.library, '${jellyfin.length}'),
          RecommendationTileGrid(tiles: [
            for (final item in jellyfin) RecommendationTile.jellyfin(item: item)
          ], contentPadding: padding),
        ] else if (library.isNotEmpty) ...[
          heading(EntityStrings.library, '${library.length}'),
          grid(library, label: false),
        ],
        if (rest.isNotEmpty) ...[
          heading(
              switch (_kind) {
                UpcomingFollowKind.person => EntityStrings.restPerson,
                UpcomingFollowKind.collection => EntityStrings.restSaga,
                _ => EntityStrings.catalogue,
              },
              '${rest.length}'),
          grid(rest),
        ],
        if (state.hasMore || state.loadingMore)
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: state.loadingMore
                    ? const CircularProgressIndicator()
                    : _Chip(EntityStrings.more,
                        selected: false,
                        onTap: () =>
                            ref.read(entityProvider(_key).notifier).loadMore()),
              ),
            ),
          ),
        if (appearances.isNotEmpty) ...[
          heading(EntityStrings.appearances,
              EntityStrings.appearancesDetail(appearances.length)),
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final t in appearances)
                    FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: () => openUpcoming(context, t.toEntry()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs,
                            vertical: AppSpacing.xxs),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: t.title,
                              style: text.bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary)),
                          TextSpan(
                              text: '  ${_subtitle(t, role: true)}',
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ])),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (upcoming.isEmpty &&
            library.isEmpty &&
            (jellyfin ?? const []).isEmpty &&
            rest.isEmpty &&
            appearances.isEmpty)
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
              child: Text(EntityStrings.nothing,
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),
      ],
      const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.router.maybePop(),
        const SingleActivator(LogicalKeyboardKey.keyS): _toggleFollow,
        const SingleActivator(LogicalKeyboardKey.keyR): _cycleRole,
        const SingleActivator(LogicalKeyboardKey.keyO): _cycleSort,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: ScrollPinnedBackButton(
            restLeft: padding.left,
            child: CustomScrollView(slivers: slivers),
          ),
        ),
      ),
    );
  }
}

class _EntityBanner extends StatelessWidget {
  const _EntityBanner(
      {required this.kind,
      required this.header,
      required this.fallbackName,
      required this.padding,
      this.posters = const [],
      this.follow});
  final UpcomingFollowKind kind;
  final EntityHeader? header;
  final String fallbackName;
  final EdgeInsets padding;

  /// Personne : ses affiches les plus connues, en mosaïque de fond.
  final List<String> posters;
  final Widget? follow;

  void _biography(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => GlassDialog(
          constraints:
              const BoxConstraints(maxWidth: AppPageLayout.compactWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(header!.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                      child: SingleChildScrollView(
                          child: Text(header!.biography!,
                              style: Theme.of(context).textTheme.bodyMedium))),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(EntityStrings.close)),
                  ),
                ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final logo = kind == UpcomingFollowKind.company ||
        kind == UpcomingFollowKind.network;
    final size = MediaQuery.sizeOf(context);
    final height = logo
        ? AppUpcomingLayout.bannerMin
        : (size.height * AppUpcomingLayout.bannerFactor)
            .clamp(AppUpcomingLayout.bannerMin, AppUpcomingLayout.bannerMax);
    final header = this.header;
    final secondary = AppColors.textPrimary.withValues(alpha: .75);
    final image = header?.image;
    final backdrop = header?.backdrop;
    final biography = header?.biography;

    Widget fade(Alignment begin, Alignment end) => DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(begin: begin, end: end, stops: const [
          0,
          .45,
          1
        ], colors: [
          AppColors.background,
          AppColors.background.withValues(alpha: .8),
          AppColors.background.withValues(alpha: 0),
        ])));

    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        // L'image s'arrête juste avant le bord du bandeau : son liseré
        // tombe sous le fondu, opaque à cet endroit. Plus de ligne.
        Padding(
          padding:
              const EdgeInsets.only(bottom: AppUpcomingLayout.bannerEdgeInset),
          child: logo
              ? const ColoredBox(color: AppColors.surface)
              : kind == UpcomingFollowKind.collection && backdrop != null
                  ? KinosImage(
                      image: ImageData(
                          path: tmdbImage(backdrop, size: 'w1280'),
                          key: 'entity-backdrop:$backdrop'),
                      fit: BoxFit.cover)
                  : kind == UpcomingFollowKind.person && posters.isNotEmpty
                      ? Opacity(
                          opacity: AppUpcomingLayout.mosaicOpacity,
                          child: _PosterMosaic(posters: posters))
                      : const SizedBox.shrink(),
        ),
        fade(Alignment.bottomCenter, Alignment.topCenter),
        if (kind == UpcomingFollowKind.person)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
                widthFactor: .7,
                heightFactor: 1,
                child: fade(Alignment.centerLeft, Alignment.centerRight)),
          ),
        Padding(
          padding: padding.copyWith(bottom: AppSpacing.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (kind == UpcomingFollowKind.person && image != null) ...[
              ClipRRect(
                borderRadius: AppRadii.cardBorder,
                child: SizedBox.square(
                  dimension: AppUpcomingLayout.portraitSize,
                  child: KinosImage(
                      image: ImageData(
                          path: tmdbImage(image, size: 'w300'),
                          key: 'entity-photo:$image'),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.5)),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (logo && image != null) ...[
                    DecoratedBox(
                      decoration: const BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: AppRadii.cardBorder),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox(
                          height: AppUpcomingLayout.followAvatar,
                          child: KinosImage(
                              image: ImageData(
                                  path: tmdbImage(image, size: 'w300'),
                                  key: 'entity-logo:$image'),
                              fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (header?.context.isNotEmpty ?? false)
                    Text(header!.context,
                        style: text.bodyMedium?.copyWith(color: secondary)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(header?.name ?? fallbackName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.displayMedium
                          ?.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (follow != null) follow!,
                      if (biography != null && biography.trim().isNotEmpty)
                        _Chip(
                            kind == UpcomingFollowKind.person
                                ? EntityStrings.biography
                                : EntityStrings.presentation,
                            selected: false,
                            onTap: () => _biography(context)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Les affiches d'une personne, côte à côte sur quelques rangées, en
/// boucle si elles ne suffisent pas à remplir la largeur.
class _PosterMosaic extends StatelessWidget {
  const _PosterMosaic({required this.posters});
  final List<String> posters;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const rows = AppUpcomingLayout.mosaicRows;
          const gap = AppSpacing.xxs;
          final height = (constraints.maxHeight - gap * (rows - 1)) / rows;
          final width = height * AppMedia.posterAspectRatio;
          final columns = (constraints.maxWidth / (width + gap)).ceil() + 1;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: gap,
                children: [
                  for (var row = 0; row < rows; row++)
                    Row(spacing: gap, children: [
                      for (var column = 0; column < columns; column++)
                        SizedBox(
                          width: width,
                          height: height,
                          child: KinosImage(
                              image: ImageData(
                                  path: tmdbImage(
                                      posters[(row * columns + column) %
                                          posters.length],
                                      size: 'w342'),
                                  key:
                                      'mosaic:${posters[(row * columns + column) % posters.length]}'),
                              fit: BoxFit.cover),
                        ),
                    ]),
                ],
              ),
            ),
          );
        },
      );
}

class _FollowButton extends StatelessWidget {
  const _FollowButton(
      {required this.label, required this.followed, required this.onTap});
  final String label;
  final bool followed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: followed,
        child: FocusRing(
          autofocus: true,
          borderRadius: AppRadii.controlBorder,
          onActivate: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: followed ? Colors.transparent : AppColors.textPrimary,
                border: Border.all(color: AppColors.textPrimary),
                borderRadius: AppRadii.controlBorder),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(followed ? Icons.check_rounded : Icons.add_rounded,
                    color: followed
                        ? AppColors.textPrimary
                        : AppColors.background),
                const SizedBox(width: AppSpacing.xxs),
                Text(label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: followed
                            ? AppColors.textPrimary
                            : AppColors.background)),
              ]),
            ),
          ),
        ),
      );
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
