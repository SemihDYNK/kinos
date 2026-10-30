import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/seerr_dashboard_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_banner_card.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/pull_to_refresh.dart';

enum RequestView { all, pending, processing, available }

RequestView requestViewOf(SeerrDashboardPosterModel poster) {
  if (poster.mediaStatus == SeerrMediaStatus.available ||
      poster.requestStatus == SeerrRequestStatus.completed) {
    return RequestView.available;
  }
  if (poster.mediaStatus == SeerrMediaStatus.pending ||
      poster.requestStatus == SeerrRequestStatus.pending) {
    return RequestView.pending;
  }
  if (poster.mediaStatus == SeerrMediaStatus.processing ||
      poster.mediaStatus == SeerrMediaStatus.partiallyAvailable ||
      poster.requestStatus == SeerrRequestStatus.approved) {
    return RequestView.processing;
  }
  return RequestView.all;
}

final requestViewProvider = StateProvider.autoDispose((ref) => RequestView.all);
final requestQueryProvider = StateProvider.autoDispose((ref) => '');
final requestTypeProvider =
    StateProvider.autoDispose<SeerrMediaType?>((ref) => null);

@RoutePage()
class SeerrScreen extends ConsumerStatefulWidget {
  const SeerrScreen({super.key});
  @override
  ConsumerState<SeerrScreen> createState() => _SeerrScreenState();
}

class _SeerrScreenState extends ConsumerState<SeerrScreen> {
  final _filters = AnchoredPopoverController();
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ref.read(seerrDashboardProvider.notifier).fetchDashboard();
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(seerrDashboardProvider).recentRequests;
    final view = ref.watch(requestViewProvider);
    final query = ref.watch(requestQueryProvider).trim().toLowerCase();
    final type = ref.watch(requestTypeProvider);
    final labels = {
      RequestView.all: context.localized.all,
      RequestView.pending: context.localized.seerrRequestStatusPending,
      RequestView.processing: context.localized.processing,
      RequestView.available: context.localized.seerrMediaStatusAvailable,
    };
    final typed = requests
        .where((poster) => type == null || poster.type == type)
        .toList();
    final shown = typed
        .where((poster) =>
            (view == RequestView.all || requestViewOf(poster) == view) &&
            (poster.title.toLowerCase().contains(query) ||
                (poster.requestedBy is SeerrUserModel &&
                    (poster.requestedBy as SeerrUserModel)
                        .label
                        .toLowerCase()
                        .contains(query))))
        .toList();
    final padding = EdgeInsets.only(
      left: AdaptiveLayout.of(context).sideBarWidth + AppSpacing.screenPadding,
      right: AppSpacing.screenPadding,
    );
    return ColoredBox(
      color: AppColors.background,
      child: PullToRefresh(
          refreshOnStart: false,
          onRefresh: _load,
          child: (context) => CustomScrollView(slivers: [
                SliverPadding(
                    padding: padding.copyWith(
                        top: AdaptiveLayout.of(context).topBarHeight +
                            AppSpacing.lg,
                        bottom: AppSpacing.lg),
                    sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          AppPageHeader(
                            title: context.localized.managementRequestsTitle,
                            subtitle:
                                context.localized.managementRequestsSubtitle,
                            trailing: FilterButton(
                              isSelected: false,
                              icon: Icons.explore_outlined,
                              label: Text(context.localized.discover),
                              onPressed: () => context.router.navigate(
                                  SeerrSearchRoute(
                                      mode: SeerrSearchMode.search)),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          LayoutBuilder(
                              builder: (context, constraints) => Wrap(
                                      spacing: AppSpacing.md,
                                      runSpacing: AppSpacing.sm,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        FrostedSurface(
                                            borderRadius:
                                                AppRadii.controlBorder,
                                            child: Padding(
                                                padding: const EdgeInsets.all(
                                                    AppSpacing.xxs),
                                                child: Wrap(
                                                    spacing: AppSpacing.xxs,
                                                    children: [
                                                      for (final entry
                                                          in labels.entries)
                                                        FilterButton(
                                                            isSelected: view ==
                                                                entry.key,
                                                            label: Text(
                                                                '${entry.value} ${entry.key == RequestView.all ? typed.length : typed.where((p) => requestViewOf(p) == entry.key).length}'),
                                                            onPressed: () => ref
                                                                .read(requestViewProvider
                                                                    .notifier)
                                                                .state = entry.key),
                                                    ]))),
                                        SizedBox(
                                            width: constraints.maxWidth.clamp(0,
                                                AppLibraryLayout.searchWidth),
                                            child: OutlinedTextField(
                                                onChanged: (text) => ref
                                                    .read(requestQueryProvider
                                                        .notifier)
                                                    .state = text,
                                                decoration: InputDecoration(
                                                    hintText: context.localized
                                                        .managementSearchRequests,
                                                    prefixIcon: const Icon(
                                                        Icons.search),
                                                    border: InputBorder.none))),
                                        AnchoredPopover(
                                            controller: _filters,
                                            popoverBuilder: (context, close) =>
                                                PopoverOptionList(
                                                    onSelected: close,
                                                    options: [
                                                      for (final entry in <(
                                                        String,
                                                        SeerrMediaType?
                                                      )>[
                                                        (
                                                          context.localized.all,
                                                          null
                                                        ),
                                                        (
                                                          context.localized
                                                              .mediaTypeMovie(
                                                                  2),
                                                          SeerrMediaType.movie
                                                        ),
                                                        (
                                                          context.localized
                                                              .mediaTypeSeries(
                                                                  2),
                                                          SeerrMediaType.tvshow
                                                        )
                                                      ])
                                                        PopoverOption(
                                                            content:
                                                                Text(entry.$1),
                                                            selected: type ==
                                                                entry.$2,
                                                            onSelect: () => ref
                                                                .read(requestTypeProvider
                                                                    .notifier)
                                                                .state = entry.$2),
                                                    ]),
                                            child: FilterButton(
                                                isSelected: type != null,
                                                icon: Icons.tune,
                                                label: Text(context.localized
                                                    .filter(2)),
                                                onPressed: _filters.toggle)),
                                      ])),
                        ]))),
                SliverPadding(
                    padding: padding,
                    sliver: SliverToBoxAdapter(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadii.controlBorder,
                                border: Border.all(color: AppColors.border)),
                            child: LayoutBuilder(
                              builder: (context, constraints) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.sm),
                                  child: Row(children: [
                                    Expanded(
                                        child: Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(
                                                start: AppManagementLayout
                                                        .requestPosterWidth +
                                                    AppSpacing.md),
                                            child: Text(context.localized.name,
                                                style: AppTypography.meta))),
                                    if (constraints.maxWidth >=
                                        AppManagementLayout
                                            .requestWideWidth) ...[
                                      SizedBox(
                                          width: AppManagementLayout
                                              .requesterWidth,
                                          child: Text(
                                              context.localized
                                                  .managementRequestedBy,
                                              style: AppTypography.meta)),
                                      SizedBox(
                                          width: AppManagementLayout
                                              .requestStatusWidth,
                                          child: Text(
                                              context
                                                  .localized.managementStatus,
                                              style: AppTypography.meta)),
                                      const SizedBox(
                                          width: AppPageLayout.toolbarHeight),
                                    ],
                                  ])),
                            )))),
                SliverPadding(
                    padding: padding,
                    sliver: SliverList.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) => DecoratedBox(
                          decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                  bottom: BorderSide(color: AppColors.border))),
                          child: SeerrRequestBannerCard(
                              key: ValueKey(shown[index].id),
                              poster: shown[index],
                              compact: true)),
                    )),
                if (shown.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: _load,
                                  child: Text(
                                      '${_failed ? context.localized.error : context.localized.noResults} · ${context.localized.refresh}')))),
                SliverPadding(
                    padding: padding.copyWith(
                        top: AppSpacing.md, bottom: AppSpacing.xxl),
                    sliver: SliverToBoxAdapter(
                        child: Text(context.localized.discoveryShortcuts,
                            style: AppTypography.meta))),
              ])),
    );
  }
}
