import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';

class SettingsScaffold extends ConsumerWidget {
  final String label;
  final bool navigation;
  final ScrollController? scrollController;
  final double itemSpacing;
  final List<Widget> items;
  final List<Widget> bottomActions;
  final bool showUserIcon;
  final bool showBackButtonNested;
  final Widget? floatingActionButton;
  const SettingsScaffold({
    required this.label,
    this.navigation = false,
    this.scrollController,
    this.itemSpacing = 0.0,
    required this.items,
    this.bottomActions = const [],
    this.floatingActionButton,
    this.showUserIcon = false,
    this.showBackButtonNested = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = MediaQuery.paddingOf(context);
    final singleLayout =
        AdaptiveLayout.layoutModeOf(context) == LayoutMode.single;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: floatingActionButton,
      body: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Flexible(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg + padding.left,
                              padding.top +
                                  AdaptiveLayout.of(context).topBarHeight +
                                  AppSpacing.lg,
                              AppSpacing.lg + padding.right,
                              AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!navigation &&
                                    (singleLayout || showBackButtonNested) &&
                                    !ref.read(argumentsStateProvider).htpcMode)
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AppSpacing.md),
                                      child: BackButton(
                                          onPressed: () =>
                                              backAction(context))),
                                AppPageHeader(title: label),
                              ]))),
                  SliverPadding(
                    padding: singleLayout
                        ? padding.copyWith(top: 0, bottom: 0)
                        : EdgeInsets.zero,
                    sliver: SliverList.separated(
                      itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          child: Align(
                              alignment: AlignmentDirectional.topStart,
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: AppPageLayout.settingsWidth),
                                  child: items[index]))),
                      separatorBuilder: (context, index) => SizedBox(
                          height: itemSpacing > 0
                              ? itemSpacing / 2
                              : navigation
                                  ? AppSpacing.xxs
                                  : 0),
                      itemCount: items.length,
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl)),
                ],
              ),
            ),
            if (bottomActions.isNotEmpty) ...{
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4).add(
                  EdgeInsets.only(bottom: padding.bottom),
                ),
                child: Row(
                  spacing: 16,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: bottomActions,
                ),
              ),
            },
          ],
        ),
      ),
    );
  }

  void backAction(BuildContext context) {
    if (kIsWeb) {
      if (AdaptiveLayout.layoutModeOf(context) == LayoutMode.single &&
          context.tabsRouter.activeIndex != 0) {
        context.tabsRouter.setActiveIndex(0);
      } else {
        context.router.pop();
      }
    } else {
      context.router.popBack();
    }
  }
}
