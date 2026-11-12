import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/dashboard/genre_browse_provider.dart';
import 'package:kinos/screens/dashboard/genre_hero.dart';
import 'package:kinos/screens/dashboard/genre_page_screen.dart';
import 'package:kinos/theme/app_theme.dart';

/// Rangée « Genres » de l'accueil : tuiles paysage (image d'un titre du
/// genre sous un voile sombre, nom au centre) qui défilent à la molette
/// horizontale, au glisser, aux flèches du titre et au clavier, et ouvrent
/// la page du genre. Remplace l'empilement d'une rangée par genre.
class GenreBrowseSection extends ConsumerWidget {
  const GenreBrowseSection(
      {required this.scope, required this.contentPadding, super.key});
  final CatalogScope scope;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(browseGenresProvider(scope)).valueOrNull;
    if (genres == null || genres.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: contentPadding,
          child: _GenreRow(
              key: ValueKey(scope),
              scope: scope,
              genres: genres,
              onOpen: (genre) => openGenrePage(context, scope, genre)),
        ),
      ),
    );
  }
}

class _GenreRow extends StatefulWidget {
  const _GenreRow(
      {required this.scope,
      required this.genres,
      required this.onOpen,
      super.key});
  final CatalogScope scope;
  final List<BrowseGenre> genres;
  final void Function(BrowseGenre genre) onOpen;

  @override
  State<_GenreRow> createState() => _GenreRowState();
}

class _GenreRowState extends State<_GenreRow> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(double width, int direction) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * width * .8)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (AppMotion.enabled(context)) {
      _scroll.animateTo(target,
          duration: AppDurations.unroll, curve: AppMotion.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final visible = constraints.maxWidth >= 1100 ? 4 : 3;
          final width =
              (constraints.maxWidth - AppSpacing.gridGap * (visible - 1)) /
                  visible;
          final inset = FocusRing.boxInset(context);
          final height = (width - inset) / AppMedia.resumeAspectRatio + inset;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Genres',
                        style: Theme.of(context).textTheme.headlineMedium)),
                for (final direction in [-1, 1])
                  FocusRing(
                    borderRadius: AppRadii.controlBorder,
                    onActivate: () => _page(constraints.maxWidth, direction),
                    child: ExcludeFocus(
                      child: IconButton(
                        onPressed: () => _page(constraints.maxWidth, direction),
                        tooltip: direction < 0
                            ? 'Défiler vers la gauche'
                            : 'Défiler vers la droite',
                        icon: Icon(direction < 0
                            ? Icons.chevron_left
                            : Icons.chevron_right),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: height,
                // Défilement horizontal : molette avec Maj, molette ou
                // pavé horizontal, glisser à la souris. La molette
                // verticale seule continue de faire défiler la page.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: false,
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.genres.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.gridGap),
                    itemBuilder: (context, index) => SizedBox(
                      width: width,
                      child: _GenreTile(
                          scope: widget.scope,
                          genre: widget.genres[index],
                          onOpen: () => widget.onOpen(widget.genres[index])),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _GenreTile extends StatelessWidget {
  const _GenreTile(
      {required this.scope, required this.genre, required this.onOpen});
  final CatalogScope scope;
  final BrowseGenre genre;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        // Le clavier amène toujours la tuile focalisée dans la rangée.
        onFocusChange: (focused) {
          if (focused) {
            Scrollable.ensureVisible(context,
                alignment: .5,
                duration: AppMotion.enabled(context)
                    ? AppDurations.hover
                    : Duration.zero);
          }
        },
        child: Semantics(
          button: true,
          label: 'Genre ${genre.label}',
          excludeSemantics: true,
          child: FocusRing(
            onActivate: onOpen,
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: Stack(fit: StackFit.expand, children: [
                // L'image part en bandeau vers la page du genre, et le nom
                // la rejoint (cf. genre_hero.dart).
                genreBackdropHero(context,
                    tag: genreImageTag(scope.kind, scope.libraryId, genre.label),
                    image: genre.image,
                    mix: 0),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: genreTitleHero(context,
                        tag: genreTitleTag(
                            scope.kind, scope.libraryId, genre.label),
                        label: genre.label,
                        big: false,
                        textAlign: TextAlign.center,
                        maxLines: 2),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
