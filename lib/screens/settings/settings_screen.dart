import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/auth_provider.dart';
import 'package:kinos/providers/update_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/settings/quick_connect_window.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/settings_scaffold.dart';
import 'package:kinos/screens/shared/default_alert_dialog.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/theme_extensions.dart';
import 'package:kinos/util/window_actions.dart';

@RoutePage()
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final scrollController = ScrollController();
  bool split(BuildContext context) =>
      AdaptiveLayout.layoutModeOf(context) == LayoutMode.dual ||
      (AdaptiveLayout.isDesktop(context) &&
          MediaQuery.sizeOf(context).width -
                  AdaptiveLayout.of(context).sideBarWidth >=
              AppManagementLayout.settingsSplitWidth);

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  late LayoutMode lastAdaptiveLayout = AdaptiveLayout.layoutModeOf(context);

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      builder: (context, content) {
        checkForNullIndex(context);
        return PopScope(
          canPop: context.tabsRouter.activeIndex == 0 || split(context),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              context.tabsRouter.setActiveIndex(0);
            }
          },
          child: !split(context)
              ? Card(
                  elevation: 0,
                  child: Stack(
                    children: [
                      _leftPane(context),
                      content,
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: AdaptiveLayout.of(context).sideBarWidth +
                            AppManagementLayout.settingsNavigationWidth +
                            AppSpacing.lg,
                        child: _leftPane(context)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: MediaQuery.paddingOf(context).left,
                        ),
                        child: AdaptiveLayout(
                            data: AdaptiveLayout.of(context)
                                .copyWith(layoutMode: LayoutMode.dual),
                            child: content),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  //We have to navigate to the first screen after switching layouts && index == 0 otherwise the dual-layout is empty
  void checkForNullIndex(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentIndex = context.tabsRouter.activeIndex;
      if (mounted && split(context) && currentIndex == 0) {
        context.tabsRouter.setActiveIndex(1);
      }
    });
  }

  IconData get deviceIcon {
    if (AdaptiveLayout.of(context).isDesktop) {
      return IconsaxPlusLinear.monitor;
    }
    switch (AdaptiveLayout.viewSizeOf(context)) {
      case ViewSize.phone:
        return IconsaxPlusLinear.mobile;
      case ViewSize.tablet:
        return IconsaxPlusLinear.monitor;
      case ViewSize.desktop:
        return IconsaxPlusLinear.monitor;
      case ViewSize.television:
        return IconsaxPlusLinear.mirroring_screen;
    }
  }

  Widget _leftPane(BuildContext context) {
    void navigateTo(PageRouteInfo route) => context.tabsRouter.navigate(route);

    bool containsRoute(PageRouteInfo route) =>
        split(context) && context.tabsRouter.current.name == route.routeName;

    final quickConnectAvailable = ref.watch(userProvider.select(
        (value) => value?.serverConfiguration?.quickConnectAvailable ?? false));

    final newRelease =
        ref.watch(updateProvider.select((value) => value.latestRelease));

    final hasNewUpdate = ref.watch(hasNewUpdateProvider);

    final isAdmin = ref.watch(userProvider
        .select((value) => value?.policy?.isAdministrator ?? false));

    return Padding(
      padding: EdgeInsetsDirectional.only(
          start: AdaptiveLayout.of(context).sideBarWidth),
      child: Container(
        color: AppColors.background,
        child: SettingsScaffold(
          label: context.localized.settings,
          scrollController: scrollController,
          showBackButtonNested:
              AdaptiveLayout.inputDeviceOf(context) != InputDevice.dPad,
          showUserIcon: false,
          navigation: true,
          items: [
            if (hasNewUpdate && newRelease != null) ...[
              Card(
                color: context.colors.secondaryContainer,
                child: SettingsListTile(
                  navigation: true,
                  label: Text(context.localized
                      .newReleaseFoundTitle(newRelease.version)),
                  subLabel: Text(context.localized.newUpdateFoundOnGithub),
                  icon: IconsaxPlusLinear.information,
                  onTap: () => navigateTo(const AboutSettingsRoute()),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.managementApplication),
              subLabel: Text(context.localized.settingsClientDesc),
              autoFocus: true,
              selected: containsRoute(const ClientSettingsRoute()),
              icon: AppIcons.series,
              onTap: () => navigateTo(const ClientSettingsRoute()),
            ),
            if (isAdmin)
              SettingsListTile(
                navigation: true,
                label: Text(context.localized.controlPanel),
                subLabel: Text(context.localized.controlPanelDesc),
                selected: containsRoute(const ControlPanelSelectionRoute()),
                icon: AppIcons.activity,
                onTap: () =>
                    const ControlPanelSelectionRoute().navigate(context),
              ),
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.settingsProfileTitle),
              subLabel: Text(context.localized.settingsProfileDesc),
              selected: containsRoute(const ProfileSettingsRoute()),
              icon: IconsaxPlusLinear.security_user,
              onTap: () => navigateTo(const ProfileSettingsRoute()),
            ),
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.settingsPlayerTitle),
              subLabel: Text(context.localized.settingsPlayerDesc),
              selected: containsRoute(const PlayerSettingsRoute()),
              icon: AppIcons.play,
              onTap: () => navigateTo(const PlayerSettingsRoute()),
            ),
            SettingsListTile(
              navigation: true,
              label: const Text('Radarr et Sonarr'),
              subLabel: const Text('URL, clé API et test de connexion'),
              selected: containsRoute(const ArrSettingsRoute()),
              icon: IconsaxPlusLinear.cloud,
              onTap: () => navigateTo(const ArrSettingsRoute()),
            ),
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.about),
              subLabel: Text("Kinos, ${context.localized.latestReleases}"),
              selected: containsRoute(const AboutSettingsRoute()),
              leading: Opacity(
                opacity: 1,
                child: KinosIconOutlined(
                  size: 24,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              onTap: () => navigateTo(const AboutSettingsRoute()),
            ),
            const FractionallySizedBox(
              widthFactor: 0.25,
              child: Divider(),
            ),
            if (quickConnectAvailable)
              SettingsListTile(
                navigation: true,
                label: Text(context.localized.settingsQuickConnectTitle),
                icon: IconsaxPlusLinear.password_check,
                onTap: () => openQuickConnectDialog(context),
              ),
            if (ref.watch(
                argumentsStateProvider.select((value) => value.htpcMode)))
              SettingsListTile(
                navigation: true,
                label: Text(context.localized.exitKinosTitle),
                icon: IconsaxPlusLinear.close_square,
                onTap: () async {
                  showDefaultAlertDialog(
                    context,
                    context.localized.exitKinosTitle,
                    context.localized.exitKinosDesc,
                    (context) async {
                      if (AdaptiveLayout.of(context).isDesktop) {
                        await quitApplication(context);
                      } else {
                        SystemNavigator.pop();
                      }
                    },
                    context.localized.close,
                    (context) => context.pop(),
                    context.localized.cancel,
                  );
                },
              ),
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.switchUser),
              icon: IconsaxPlusLinear.arrow_swap_horizontal,
              contentColor: AppColors.textPrimary,
              onTap: () async {
                await ref.read(userProvider.notifier).logoutUser();
                context.router.replaceAll([LoginRoute()]);
              },
            ),
            SettingsListTile(
              navigation: true,
              label: Text(context.localized.logout),
              icon: IconsaxPlusLinear.logout,
              contentColor: Theme.of(context).colorScheme.error,
              onTap: () {
                final user = ref.read(userProvider);
                showDialog(
                  context: context,
                  builder: (context) => GlassAlertDialog(
                    title: Text(context.localized
                        .logoutUserPopupTitle(user?.name ?? "")),
                    scrollable: true,
                    content: Text(
                      context.localized.logoutUserPopupContent(
                          user?.name ?? "", user?.credentials.url ?? ""),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.localized.cancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom().copyWith(
                          iconColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.onErrorContainer),
                          foregroundColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.onErrorContainer),
                          backgroundColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.errorContainer),
                        ),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logOutUser();
                          if (context.mounted) {
                            context.router.replaceAll([LoginRoute()]);
                          }
                        },
                        child: Text(context.localized.logout),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
