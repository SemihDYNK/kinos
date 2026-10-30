import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/theme/app_theme_provider.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/screens/dashboard/continue_watching_section.dart';
import 'package:kinos/screens/dashboard/hero_carousel.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

/// Dégradé limité à la hauteur réelle bandeau + reprise, sans débordement.
class HomeHeroSection extends ConsumerWidget {
  const HomeHeroSection(
      {required this.heroItems,
      required this.resumeItems,
      required this.contentPadding,
      this.actionsBuilder,
      this.footerSliver,
      super.key});
  final List<ItemBaseModel> heroItems;
  final List<ItemBaseModel> resumeItems;
  final EdgeInsets contentPadding;
  final Widget? footerSliver;
  final Widget Function(BuildContext context, ItemBaseModel item)?
      actionsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebar = AdaptiveLayout.of(context).sideBarWidth;
    if (heroItems.isEmpty) {
      return ContinueWatchingSection(
          items: resumeItems, contentPadding: contentPadding);
    }
    final tint =
        ref.watch(heroPaletteProvider.select((palette) => palette.tint));
    final decoration = BoxDecoration(
        gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [tint, tint, AppColors.background],
      stops: const [0, AppHeroLayout.imageFadeStart, 1],
    ));
    return SliverStack(children: [
      SliverPositioned.fill(
          child: AppMotion.enabled(context)
              ? AnimatedContainer(
                  duration: AppDurations.heroSlide,
                  curve: AppMotion.easeOut,
                  decoration: decoration)
              : DecoratedBox(decoration: decoration)),
      SliverMainAxisGroup(slivers: [
        SliverToBoxAdapter(
            child: HeroCarousel(
                items: heroItems,
                contentStart: sidebar,
                actionsBuilder: actionsBuilder)),
        if (footerSliver != null) footerSliver!,
        if (resumeItems.isNotEmpty)
          SliverPadding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.lg, bottom: AppSpacing.lg),
              sliver: ContinueWatchingSection(
                  items: resumeItems, contentPadding: contentPadding)),
      ]),
    ]);
  }
}
