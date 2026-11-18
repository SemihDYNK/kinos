import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/seerr/seerr_models.dart' show SeerrMediaType;
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/key_hint.dart';

import 'upcoming_logic.dart';
import 'upcoming_models.dart';
import 'upcoming_providers.dart';
import 'upcoming_strings.dart';

/// Les films et séries qui sortent bientôt : le prochain titre suivi en
/// bandeau, puis une frise unique (suivis et grandes sorties).
@RoutePage()
class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  var _type = UpcomingTypeFilter.all;
  var _scope = UpcomingScopeFilter.both;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(upcomingProvider.notifier).refresh();
    });
  }

  void _cycleType() => setState(() => _type = UpcomingTypeFilter
      .values[(_type.index + 1) % UpcomingTypeFilter.values.length]);

  void _cycleScope() => setState(() => _scope = UpcomingScopeFilter
      .values[(_scope.index + 1) % UpcomingScopeFilter.values.length]);

  void _toggleGrouping() {
    final byMonth = ref.read(upcomingProvider).settings?.byMonth ?? false;
    ref.read(upcomingProvider.notifier).setByMonth(!byMonth);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(upcomingProvider);
    final locale = Localizations.localeOf(context).toString();
    final padding = AdaptiveLayout.adaptivePadding(context,
        horizontalPadding: AppSpacing.screenPadding);
    final entries =
        filterUpcoming(state.entries ?? const [], type: _type, scope: _scope);
    final sections = groupUpcoming(entries, DateTime.now(),
        byMonth: state.settings?.byMonth ?? false);
    final featured = upcomingFeatured(state.entries ?? const []);
    final text = Theme.of(context).textTheme;

    final slivers = <Widget>[
      if (featured.isNotEmpty)
        SliverToBoxAdapter(
            child: _Banner(entries: featured, padding: padding, locale: locale))
      else
        SliverPadding(
          // Sous la capsule de navigation, posée par-dessus la page.
          padding: padding.copyWith(
              top: AppTopNavigation.contentInset + AppSpacing.lg),
          sliver: SliverToBoxAdapter(
              child: Text(UpcomingStrings.title, style: text.displaySmall)),
        ),
      SliverPadding(
        padding: padding.copyWith(top: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: _Controls(
            type: _type,
            scope: _scope,
            byMonth: state.settings?.byMonth ?? false,
            onType: (t) => setState(() => _type = t),
            onScope: (s) => setState(() => _scope = s),
            onByMonth: (m) => ref.read(upcomingProvider.notifier).setByMonth(m),
            status: [
              if (state.settings != null) state.settings!.region,
              '${state.follows.length} suivis',
              if (state.refreshing)
                UpcomingStrings.refreshing
              else if (state.at != null)
                'mis à jour ${UpcomingStrings.updated(state.at)}',
            ].join(' · '),
            onRefresh: () =>
                ref.read(upcomingProvider.notifier).refresh(force: true),
          ),
        ),
      ),
      if (state.follows.isNotEmpty)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.lg),
          sliver:
              SliverToBoxAdapter(child: _FollowsRow(follows: state.follows)),
        ),
      if (state.entries == null)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Text(
                state.failed ? UpcomingStrings.failed : UpcomingStrings.loading,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        )
      else if (sections.isEmpty)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Text(
                state.follows.isEmpty
                    ? UpcomingStrings.noFollows
                    : UpcomingStrings.empty,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        )
      else
        for (final section in sections) ...[
          _SectionHeading(section: section, padding: padding, locale: locale),
          RecommendationTileGrid(
              tiles: [for (final e in section.entries) upcomingTile(e, locale)],
              contentPadding: padding),
        ],
      if (state.entries != null && state.follows.isEmpty && sections.isNotEmpty)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Text(UpcomingStrings.noFollows,
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF): _cycleType,
        const SingleActivator(LogicalKeyboardKey.keyG): _cycleScope,
        const SingleActivator(LogicalKeyboardKey.keyV): _toggleGrouping,
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            ref.read(upcomingProvider.notifier).refresh(force: true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(slivers: slivers),
        ),
      ),
    );
  }
}

/// La tuile d'un titre à venir, au style de l'accueil : date en pastille,
/// « À demander » ou le statut de la demande sur la jaquette, raisons et
/// type de sortie en dessous.
///
/// [subtitle] remplace la légende (année, rôle, sur les pages à suivre) ;
/// sans [pill], pas de date sur la jaquette ; [label] montre « À
/// demander » ou le statut (inutile pour un titre de la bibliothèque).
RecommendationTile upcomingTile(UpcomingEntry entry, String locale,
    {String? subtitle, bool pill = true, bool label = true}) {
  final image = entry.posterPath == null
      ? null
      : ImageData(
          path: tmdbImage(entry.posterPath!),
          key: 'upcoming:${entry.identity}');
  return RecommendationTile(
    identity: ('upcoming', entry.identity),
    previewImage: image,
    title: entry.title,
    subtitle: subtitle ?? UpcomingStrings.caption(entry),
    buildPoster: (context) => _UpcomingPoster(
        entry: entry, image: image, locale: locale, pill: pill, label: label),
    navigate: (context) => openUpcoming(context, entry, image: image),
  );
}

/// Ouvre la page d'un suivi : personne, studio, chaîne, saga ; une série
/// ouvre sa fiche.
Future<void> openFollow(BuildContext context, UpcomingFollow follow) {
  if (follow.kind == UpcomingFollowKind.tv) {
    return openUpcoming(
        context,
        UpcomingEntry(
            type: 'tv',
            id: follow.id,
            title: follow.name,
            release: UpcomingRelease.unknown,
            posterPath: follow.image));
  }
  return context.router.push(
      EntityRoute(kind: follow.kind.name, id: follow.id, name: follow.name));
}

/// Ouvre la fiche Jellyfin si le titre y est, sinon sa fiche Seerr (où
/// le demander).
Future<void> openUpcoming(BuildContext context, UpcomingEntry entry,
    {ImageData? image}) {
  if (entry.jellyfinId case final id?) {
    return RecommendationTile.cachedJellyfin(
            itemId: id,
            title: entry.title,
            image: image ?? ImageData(),
            isMovie: entry.isMovie,
            year: entry.date?.year)
        .navigate(context);
  }
  return pushMediaRoute(
      context,
      SeerrDetailsRoute(
        tag: MediaNavigationScope.tagOf(context),
        mediaType: entry.type,
        tmdbId: entry.id,
        poster: SeerrDashboardPosterModel(
            id: entry.identity,
            type: entry.isMovie ? SeerrMediaType.movie : SeerrMediaType.tvshow,
            tmdbId: entry.id,
            title: entry.title,
            overview: '',
            images: ImagesData(primary: image),
            mediaStatus: entry.status,
            jellyfinItemId: entry.jellyfinId,
            releaseYear: entry.date?.year.toString()),
      ));
}

class _UpcomingPoster extends StatelessWidget {
  const _UpcomingPoster(
      {required this.entry,
      required this.image,
      required this.locale,
      this.pill = true,
      this.label = true});
  final UpcomingEntry entry;
  final ImageData? image;
  final String locale;
  final bool pill;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (entry.status) {
      _ when !entry.requested => (Icons.add_rounded, UpcomingStrings.toRequest),
      SeerrMediaStatus.available || SeerrMediaStatus.partiallyAvailable => (
          Icons.check_rounded,
          UpcomingStrings.available
        ),
      _ => (Icons.schedule_rounded, UpcomingStrings.requested),
    };
    final date = pill ? UpcomingStrings.pill(entry, locale) : '';
    final meta = AppTypography.meta.copyWith(color: AppColors.textPrimary);
    return Stack(fit: StackFit.expand, children: [
      if (image case final image?)
        KinosImage(image: image, fit: BoxFit.cover)
      else
        const Center(
            child: Icon(Icons.movie_creation_outlined,
                color: AppColors.textDisabled)),
      if (this.label)
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: .6,
            widthFactor: 1,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                  AppColors.scrim.withValues(alpha: .85),
                  Colors.transparent
                ]))),
          ),
        ),
      if (date.isNotEmpty)
        Positioned(
          left: AppSpacing.xs,
          top: AppSpacing.xs,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: AppColors.scrim.withValues(alpha: .7),
                borderRadius:
                    const BorderRadius.all(Radius.circular(AppSpacing.xxs))),
            child: Padding(
              padding: AppUpcomingLayout.keyHintPadding,
              child: Text(date, style: meta),
            ),
          ),
        ),
      if (this.label)
        Positioned(
          left: AppSpacing.xs,
          right: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Row(children: [
            Icon(icon, size: meta.fontSize, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: meta)),
          ]),
        ),
    ]);
  }
}

/// Le bandeau : les prochains titres suivis et les grandes sorties, une
/// diapo à la fois, comme le carrousel de l'accueil (manuel : flèches,
/// ← → au clavier).
class _Banner extends StatefulWidget {
  const _Banner(
      {required this.entries, required this.padding, required this.locale});
  final List<UpcomingEntry> entries;
  final EdgeInsets padding;
  final String locale;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  int _index = 0;

  UpcomingEntry get _current =>
      widget.entries[_index.clamp(0, widget.entries.length - 1)];

  @override
  void didUpdateWidget(covariant _Banner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.entries.isEmpty
        ? null
        : oldWidget.entries[_index.clamp(0, oldWidget.entries.length - 1)];
    final kept =
        widget.entries.indexWhere((e) => e.identity == previous?.identity);
    _index = kept < 0 ? 0 : kept;
  }

  void _go(int delta) {
    if (widget.entries.length < 2) return;
    setState(() => _index = (_index + delta) % widget.entries.length);
    _precache();
  }

  ImageData? _image(UpcomingEntry entry) {
    final backdrop = entry.backdropPath ?? entry.posterPath;
    return backdrop == null
        ? null
        : ImageData(
            path: tmdbImage(backdrop, size: 'w1280'),
            key: 'upcoming-banner:${entry.identity}');
  }

  void _precache() {
    final length = widget.entries.length;
    if (length < 2) return;
    for (final i in {(_index + 1) % length, (_index - 1) % length}) {
      final image = _image(widget.entries[i]);
      if (image != null) {
        precacheImage(image.imageProvider, context, onError: (_, __) {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _current;
    final height =
        (MediaQuery.sizeOf(context).height * AppUpcomingLayout.bannerFactor)
            .clamp(AppUpcomingLayout.bannerMin, AppUpcomingLayout.bannerMax);
    final image = _image(entry);
    final secondary =
        AppColors.textPrimary.withValues(alpha: .75); // cf. Texte sur image
    final text = Theme.of(context).textTheme;
    final duration =
        AppMotion.enabled(context) ? AppDurations.heroSlide : Duration.zero;
    final count = widget.entries.length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          // Jusqu'au bord de la fenêtre, derrière la capsule et la barre.
          AnimatedSwitcher(
            duration: duration,
            child: KeyedSubtree(
              key: ValueKey(entry.identity),
              child: image != null
                  ? KinosImage(image: image, fit: BoxFit.cover)
                  : const ColoredBox(color: AppColors.surface),
            ),
          ),
          // Fondu vers le fond de la page, dans sa couleur exacte : aucune
          // ligne là où le bandeau s'arrête.
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: AppUpcomingLayout.bannerScrimHeight,
              widthFactor: 1,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [
                    0,
                    .3,
                    1
                  ],
                          colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: .85),
                    AppColors.background.withValues(alpha: 0),
                  ]))),
            ),
          ),
          Padding(
            padding: widget.padding.copyWith(bottom: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: duration,
                    layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.bottomLeft,
                        children: [...previous, if (current != null) current]),
                    child: Column(
                      key: ValueKey(entry.identity),
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(UpcomingStrings.bannerDate(entry, widget.locale),
                            style: text.bodyMedium?.copyWith(color: secondary)),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.displayMedium
                                ?.copyWith(color: AppColors.textPrimary)),
                        if (entry.reasons.isNotEmpty || entry.big) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                              entry.reasons.isNotEmpty
                                  ? entry.reasons.join(' · ')
                                  : UpcomingStrings.bigRelease,
                              style:
                                  text.bodyMedium?.copyWith(color: secondary)),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _BannerAction(entry: entry, image: image),
                      ],
                    ),
                  ),
                ),
                if (count > 1)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < count; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xxs),
                        child: AnimatedContainer(
                          duration: duration,
                          width: i == _index ? AppSpacing.lg : AppSpacing.xs,
                          height: AppSpacing.xxs,
                          decoration: BoxDecoration(
                              color: AppColors.textPrimary
                                  .withValues(alpha: i == _index ? 1 : .35),
                              borderRadius: const BorderRadius.all(
                                  Radius.circular(AppSpacing.xxs))),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    _Arrow(
                        icon: Icons.chevron_left_rounded, onTap: () => _go(-1)),
                    const SizedBox(width: AppSpacing.xxs),
                    _Arrow(
                        icon: Icons.chevron_right_rounded, onTap: () => _go(1)),
                  ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.entry, required this.image});
  final UpcomingEntry entry;
  final ImageData? image;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MediaNavigation(
      key: ValueKey(entry.identity),
      previewImage: image,
      builder: (context) => FocusRing(
        borderRadius: AppRadii.controlBorder,
        focusNode: MediaNavigationScope.focusOf(context),
        onActivate: () => openUpcoming(context, entry),
        child: DecoratedBox(
          decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: AppRadii.controlBorder),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!entry.requested) ...[
                const Icon(Icons.add_rounded, color: AppColors.background),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Text(
                  entry.requested
                      ? UpcomingStrings.open
                      : UpcomingStrings.toRequest,
                  style:
                      text.labelLarge?.copyWith(color: AppColors.background)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.type,
    required this.scope,
    required this.byMonth,
    required this.onType,
    required this.onScope,
    required this.onByMonth,
    required this.status,
    required this.onRefresh,
  });
  final UpcomingTypeFilter type;
  final UpcomingScopeFilter scope;
  final bool byMonth;
  final ValueChanged<UpcomingTypeFilter> onType;
  final ValueChanged<UpcomingScopeFilter> onScope;
  final ValueChanged<bool> onByMonth;
  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget group(List<Widget> chips, String key) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxs,
        children: [...chips, KeyHint(key)]);
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        group([
          for (final (value, label) in [
            (UpcomingTypeFilter.all, UpcomingStrings.all),
            (UpcomingTypeFilter.movies, UpcomingStrings.movies),
            (UpcomingTypeFilter.series, UpcomingStrings.series),
          ])
            _Chip(label, selected: type == value, onTap: () => onType(value)),
        ], 'F'),
        group([
          for (final (value, label) in [
            (UpcomingScopeFilter.both, UpcomingStrings.both),
            (UpcomingScopeFilter.followed, UpcomingStrings.followed),
            (UpcomingScopeFilter.big, UpcomingStrings.big),
          ])
            _Chip(label, selected: scope == value, onTap: () => onScope(value)),
        ], 'G'),
        group([
          _Chip(UpcomingStrings.byWeek,
              selected: !byMonth, onTap: () => onByMonth(false)),
          _Chip(UpcomingStrings.byMonth,
              selected: byMonth, onTap: () => onByMonth(true)),
        ], 'V'),
        group([
          _Chip(UpcomingStrings.refresh, selected: false, onTap: onRefresh),
        ], 'R'),
        Text(status,
            style: AppTypography.meta.copyWith(color: AppColors.textSecondary)),
      ],
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(
      {required this.section, required this.padding, required this.locale});
  final UpcomingSection section;
  final EdgeInsets padding;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final (title, detail) = UpcomingStrings.section(section, locale);
    final text = Theme.of(context).textTheme;
    return SliverPadding(
      padding: padding.copyWith(top: AppSpacing.xl, bottom: AppSpacing.sm),
      sliver: SliverToBoxAdapter(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: title, style: text.displaySmall),
          if (detail != null && detail.isNotEmpty)
            TextSpan(
                text: '   $detail',
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ])),
      ),
    );
  }
}

/// « Vos suivis » : une pastille par suivi ; Entrée ou clic droit pour ne
/// plus le suivre.
class _FollowsRow extends ConsumerWidget {
  const _FollowsRow({required this.follows});
  final List<UpcomingFollow> follows;

  Future<void> _menu(BuildContext context, WidgetRef ref, UpcomingFollow follow,
      Offset? at) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = at ?? box.localToGlobal(box.size.bottomLeft(Offset.zero));
    final choice = await showMenu<bool>(
        context: context,
        position: RelativeRect.fromRect(
            origin & const Size(1, 1), Offset.zero & overlay.size),
        items: [
          const PopupMenuItem(value: false, child: Text('Ouvrir')),
          const PopupMenuItem(
              value: true, child: Text(UpcomingStrings.unfollow)),
        ]);
    if (choice == true) {
      await ref.read(upcomingProvider.notifier).unfollow(follow.key);
    } else if (choice == false && context.mounted) {
      await openFollow(context, follow);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(UpcomingStrings.followsTitle, style: text.headlineMedium),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final follow in follows)
            Builder(
              builder: (context) => GestureDetector(
                onSecondaryTapDown: (d) =>
                    _menu(context, ref, follow, d.globalPosition),
                child: FocusRing(
                  borderRadius: AppRadii.cardBorder,
                  onActivate: () => openFollow(context, follow),
                  child: SizedBox(
                    width: AppUpcomingLayout.followWidth,
                    child: Column(children: [
                      _FollowAvatar(follow: follow),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(follow.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta
                              .copyWith(color: AppColors.textPrimary)),
                      Text(_kind(follow),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta
                              .copyWith(color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    ]);
  }

  static String _kind(UpcomingFollow follow) => switch (follow.kind) {
        UpcomingFollowKind.person => follow.role == UpcomingRole.directing
            ? UpcomingStrings.asDirector
            : UpcomingStrings.asActor,
        UpcomingFollowKind.company => UpcomingStrings.studio,
        UpcomingFollowKind.network => UpcomingStrings.network,
        UpcomingFollowKind.collection => UpcomingStrings.saga,
        UpcomingFollowKind.tv => UpcomingStrings.series,
      };
}

class _FollowAvatar extends StatelessWidget {
  const _FollowAvatar({required this.follow});
  final UpcomingFollow follow;

  @override
  Widget build(BuildContext context) {
    const size = AppUpcomingLayout.followAvatar;
    final logo = follow.kind == UpcomingFollowKind.company ||
        follow.kind == UpcomingFollowKind.network;
    final image = follow.image;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(logo ? AppRadii.card : size / 2),
        child: ColoredBox(
          color: logo ? AppColors.textPrimary : AppColors.surfaceHigh,
          child: image == null
              ? Center(
                  child: Text(
                      follow.name.isEmpty ? '?' : follow.name[0].toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium))
              : Padding(
                  padding: EdgeInsets.all(logo ? AppSpacing.xs : 0),
                  child: KinosImage(
                      image: ImageData(
                          path: tmdbImage(image, size: 'w185'),
                          key: 'follow:${follow.key}'),
                      fit: logo ? BoxFit.contain : BoxFit.cover),
                ),
        ),
      ),
    );
  }
}
