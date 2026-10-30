import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_detail_providers.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/screens/details_screens/components/media_meta_line.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

/// Consultation depuis l’accueil ; la gestion Arr reste accessible dans « … ».
@RoutePage()
class ArrTitleDetailsScreen extends ConsumerWidget {
  const ArrTitleDetailsScreen(
      {required this.service,
      required this.id,
      required this.title,
      this.image,
      this.tag,
      super.key});
  final ArrService service;
  final int id;
  final String title;
  final ImageData? image;
  final Object? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (service: service, id: id);
    final state = ref.watch(arrDetailProvider(key));
    final entry = state.entry;
    final fanart = entry?.fanartUrl;
    return MediaNavigationScope(
        tag: tag,
        child: MediaDetailScaffold(
          label: entry?.title ?? title,
          title: entry?.title ?? title,
          paletteId: 'arr-${service.name}-$id',
          cinematic: true,
          useTitleLogo: false,
          backDrops: ImagesData(
              primary: image ??
                  (entry?.posterUrl == null
                      ? null
                      : ImageData(
                          path: entry!.posterUrl!,
                          key: 'arr-${service.name}-$id-poster')),
              backDrop: fanart == null
                  ? null
                  : [
                      ImageData(
                          path: fanart, key: 'arr-${service.name}-$id-fanart')
                    ]),
          metaLine: entry == null
              ? ''
              : buildMediaMetaLine(
                  year: entry.year,
                  extras: [
                    if (entry.runtimeMinutes case final minutes?) '${minutes}m'
                  ],
                  communityRating: entry.rating,
                  genres: entry.genres),
          onRefresh: entry == null
              ? null
              : () => ref.read(arrDetailProvider(key).notifier).refresh(),
          heroContent: entry?.overview?.isNotEmpty == true
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppDetailLayout.movieSynopsisWidth),
                  child: Text(entry!.overview!,
                      style: Theme.of(context).textTheme.bodyMedium))
              : null,
          actions: (context) => [
            ItemActionButton(
                icon: const Icon(Icons.tune),
                label: Text('Gérer dans ${service.label}'),
                action: () => context.router
                    .push(ArrDetailRoute(service: service, id: id)))
          ],
          content: (context, padding) => [
            if (state.error != null)
              SliverToBoxAdapter(
                  child: Padding(
                      padding: padding,
                      child: TextButton(
                          onPressed: () => ref
                              .read(arrDetailProvider(key).notifier)
                              .refresh(),
                          child:
                              const Text('Fiche indisponible · Réessayer')))),
            if (entry != null)
              SliverToBoxAdapter(
                  child: MediaInfoSection(
                      people: const [],
                      cinematic: true,
                      info: [
                        if (entry.runtimeMinutes case final minutes?)
                          (label: 'Durée', value: '${minutes}m'),
                        if (entry.genres.isNotEmpty)
                          (label: 'Genres', value: entry.genres.join(', ')),
                        if (entry.year case final year?)
                          (label: 'Année', value: '$year'),
                      ],
                      contentPadding: padding)),
          ],
        ));
  }
}
