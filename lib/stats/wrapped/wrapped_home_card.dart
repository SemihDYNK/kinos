import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/theme/palette_service_provider.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';

import '../stats_screen.dart' show formatHours, viewingEventsProvider;
import '../viewing_stats.dart';
import 'wrapped_screen.dart' show wrappedAvailable;
import 'wrapped_slides.dart' show storyColor, storyInk;

/// La carte masquée pour [year] (par sa croix).
String _hiddenKey(int year) => 'wrappedHomeHidden:$year';

final _wrappedCardHiddenProvider = StateProvider.family<bool, int>((ref,
        year) =>
    ref.watch(sharedPreferencesProvider).getBool(_hiddenKey(year)) ?? false);

void _hideWrappedCard(WidgetRef ref, int year) {
  ref.read(_wrappedCardHiddenProvider(year).notifier).state = true;
  ref.read(sharedPreferencesProvider).setBool(_hiddenKey(year), true);
}

/// L'image de fond du film de l'année et sa teinte.
final _wrappedCardArtProvider = FutureProvider.autoDispose
    .family<({ImageData? backdrop, Color? tint}), String>((ref, id) async {
  final response = await ref
      .read(jellyApiProvider)
      .usersUserIdItemsGet(ids: [id], enableUserData: false);
  final dto = response.body?.items?.firstOrNull;
  if (dto == null) return (backdrop: null, tint: null);
  final item = ItemBaseModel.fromBaseDto(dto, ref);
  final backdrop = item.images?.backDrop?.firstOrNull ?? item.images?.primary;
  if (backdrop == null) return (backdrop: null, tint: null);
  final palette = await ref
      .read(paletteServiceProvider)
      .forItem(itemId: 'wrapped-card:$id', image: backdrop.imageProvider);
  return (backdrop: backdrop, tint: palette.isFallback ? null : palette.tint);
});

/// L'annonce du Wrapped sur l'accueil, en décembre : une carte large entre
/// « Continuer à regarder » et les rangées suivantes, sur l'image de fond
/// du film de l'année fondue dans sa couleur, « 2026 » en filigrane. Elle
/// ouvre le Wrapped, et reste là tout décembre sauf si on la masque.
class WrappedHomeCard extends ConsumerWidget {
  const WrappedHomeCard({required this.contentPadding, this.today, super.key});
  final EdgeInsets contentPadding;

  /// Le jour qui décide de l'affichage (aujourd'hui ; fixé dans les tests).
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today ?? DateTime.now();
    final year = now.year;
    // En décembre seulement (ou à tout moment avec KINOS_WRAPPED_ANYTIME).
    // Hors saison, le mode de test (KINOS_WRAPPED_ANYTIME) l'affiche
    // toujours, même masquée.
    final testing = wrappedAvailable(year, now: DateTime(year, 1, 1));
    final visible = testing ||
        (now.month == 12 && !ref.watch(_wrappedCardHiddenProvider(year)));
    final events =
        visible ? ref.watch(viewingEventsProvider).valueOrNull : null;
    if (events == null) return const SliverToBoxAdapter();
    final stats = computeStats(
        events, ref.watch(kinosRatingsProvider), StatsPeriod(year: year));
    if (stats.films < AppWrapped.homeMinFilms) {
      return const SliverToBoxAdapter();
    }
    final best = stats.topRated.firstOrNull?.event;
    final art = best?.jellyfinId == null
        ? null
        : ref.watch(_wrappedCardArtProvider(best!.jellyfinId!)).valueOrNull;
    final ground = storyColor(art?.tint ?? AppColors.heroFallback);
    final ink = storyInk(ground);
    final text = Theme.of(context).textTheme;
    final cond = AppTypography.heroEditorial.copyWith(color: ink, height: .9);

    // L'ouvrir ne la retire pas : on peut revoir son année tout le mois.
    void open() => context.router.root.push(YearWrappedRoute(year: year));

    return SliverPadding(
      padding: contentPadding.copyWith(top: AppSpacing.lg, bottom: 0),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: AppWrapped.homeCardHeight,
          child: FocusRing(
            onActivate: open,
            pressMotion: true,
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: ground),
                if (art?.backdrop case final image?)
                  KinosImage(
                      image: image,
                      alignment: AppHeroLayout.imageAlignment,
                      disableBlur: true),
                // La couleur du film, pleine à gauche sous le texte, qui
                // laisse voir l'image à droite.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      stops: const [0, .45, .85],
                      colors: [
                        ground,
                        ground.withValues(alpha: .85),
                        ground.withValues(alpha: .15),
                      ],
                    ),
                  ),
                ),
                // L'année en filigrane, centrée en hauteur : la boîte du
                // texte garde sous les chiffres la place d'un jambage qu'ils
                // n'ont pas, d'où le léger décalage vers le bas.
                Positioned.fill(
                  right: AppSpacing.lg,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Transform.translate(
                      offset: const Offset(0,
                          AppWrapped.homeCardWatermark * AppWrapped.digitDrop),
                      child: Text('$year',
                          style: cond.copyWith(
                              fontSize: AppWrapped.homeCardWatermark,
                              height: 1,
                              color: ink.withValues(alpha: .12))),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('VOTRE WRAPPED EST ARRIVÉ',
                                style: AppTypography.overline.copyWith(
                                    color: ink.withValues(alpha: .75),
                                    letterSpacing: 4)),
                            const SizedBox(height: AppSpacing.xs),
                            Text('VOTRE ANNÉE $year',
                                style: cond.copyWith(
                                    fontSize: AppWrapped.homeCardTitle)),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                                '${stats.films} films · ${formatHours(stats.seconds)}'
                                '${best == null ? '' : ' · ${best.title}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyMedium?.copyWith(
                                    color: ink.withValues(alpha: .8))),
                          ]),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: open,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Voir mon année'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: 'Masquer',
                      onPressed: () => _hideWrappedCard(ref, year),
                      icon: Icon(Icons.close_rounded,
                          color: ink.withValues(alpha: .75)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
