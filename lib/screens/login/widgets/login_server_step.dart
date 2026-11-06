import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/discovery_provider.dart';
import 'package:kinos/services/local_network_permission.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/login/widgets/login_step_parts.dart';

/// Étape 1 : choisir un serveur.
///
/// Les serveurs enregistrés précèdent les serveurs découverts. Chaque rangée
/// est une cible clavier complète ; la découverte expose toujours un état
/// lisible (recherche, résultat vide, permission, échec) au lieu de laisser
/// un espace vide ou une simple notification.
class LoginServerStep extends StatelessWidget {
  const LoginServerStep({
    required this.savedServers,
    required this.discoveredServers,
    required this.onServerSelected,
    required this.onAddServer,
    required this.onRetryDiscovery,
    required this.onRequestPermission,
    this.onBackToProfiles,
    this.connectingAddress,
    this.selectedAddress,
    this.errorMessage,
    this.allowDiscovery = true,
    super.key,
  });

  final List<DiscoveryInfo> savedServers;
  final AsyncValue<List<DiscoveryInfo>> discoveredServers;
  final ValueChanged<DiscoveryInfo> onServerSelected;
  final VoidCallback onAddServer;
  final VoidCallback onRetryDiscovery;
  final VoidCallback onRequestPermission;
  final VoidCallback? onBackToProfiles;
  final String? connectingAddress;
  final String? selectedAddress;
  final String? errorMessage;
  final bool allowDiscovery;

  @override
  Widget build(BuildContext context) {
    final localized = context.localized;
    final savedAddresses = {for (final server in savedServers) server.address};
    final discovered = discoveredServers.valueOrNull ?? const <DiscoveryInfo>[];
    final newServers = [
      for (final server in discovered)
        if (!savedAddresses.contains(server.address)) server,
    ];
    final hasSaved = savedServers.isNotEmpty;
    final connecting = connectingAddress != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBackToProfiles != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: LoginFocusAction(
              onActivate: onBackToProfiles,
              child: TextButton.icon(
                key: const Key('login.backToProfiles'),
                onPressed: onBackToProfiles,
                icon: const Icon(IconsaxPlusLinear.arrow_left_2),
                label: Text(localized.backToProfiles),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        LoginStepHeader(
          step: 1,
          total: 2,
          title: localized.loginServerStepTitle,
          description: localized.loginServerStepDescription,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          LoginInlineError(errorMessage!),
        ],
        if (hasSaved) ...[
          const SizedBox(height: AppSpacing.xl),
          LoginSectionLabel(localized.savedServers),
          const SizedBox(height: AppSpacing.xs),
          for (var index = 0; index < savedServers.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            _ServerRow(
              key: ValueKey(savedServers[index].address),
              server: savedServers[index],
              autofocus: index == 0,
              selected: selectedAddress == savedServers[index].address,
              connecting: connectingAddress == savedServers[index].address,
              disabled: connecting &&
                  connectingAddress != savedServers[index].address,
              onTap: () => onServerSelected(savedServers[index]),
            ),
          ],
        ],
        if (allowDiscovery) ...[
          const SizedBox(height: AppSpacing.xl),
          LoginSectionLabel(localized.discoveredServers),
          const SizedBox(height: AppSpacing.xs),
          _DiscoveryContent(
            servers: newServers,
            savedCount: savedServers.length,
            asyncServers: discoveredServers,
            onServerSelected: onServerSelected,
            onRetryDiscovery: onRetryDiscovery,
            onRequestPermission: onRequestPermission,
            connectingAddress: connectingAddress,
            selectedAddress: selectedAddress,
            connecting: connecting,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        LoginFocusAction(
          autofocus: !hasSaved,
          onActivate: connecting ? null : onAddServer,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('login.addServer'),
              onPressed: connecting ? null : onAddServer,
              icon: const Icon(IconsaxPlusLinear.add),
              label: Text(localized.addServer),
            ),
          ),
        ),
        if (connectingAddress != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              localized.connectToServer(_displayName(
                  connectingAddress!, [...savedServers, ...newServers])),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  String _displayName(String address, List<DiscoveryInfo> servers) {
    for (final server in servers) {
      if (server.address == address) {
        return server.name.trim().isEmpty ? server.address : server.name;
      }
    }
    return address;
  }
}

class _DiscoveryContent extends StatelessWidget {
  const _DiscoveryContent({
    required this.servers,
    required this.savedCount,
    required this.asyncServers,
    required this.onServerSelected,
    required this.onRetryDiscovery,
    required this.onRequestPermission,
    required this.connectingAddress,
    required this.selectedAddress,
    required this.connecting,
  });

  final List<DiscoveryInfo> servers;
  final int savedCount;
  final AsyncValue<List<DiscoveryInfo>> asyncServers;
  final ValueChanged<DiscoveryInfo> onServerSelected;
  final VoidCallback onRetryDiscovery;
  final VoidCallback onRequestPermission;
  final String? connectingAddress;
  final String? selectedAddress;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final localized = context.localized;
    return asyncServers.when(
      loading: () => LoginStatusBlock(
        key: const Key('login.discovery.loading'),
        showProgress: true,
        title: localized.discoveringServers,
      ),
      error: (error, stackTrace) {
        if (error is LocalNetworkPermissionDeniedException) {
          return LoginStatusBlock(
            key: const Key('login.discovery.permission'),
            icon: IconsaxPlusLinear.lock_1,
            title: localized.localNetworkPermissionTitle,
            description: localized.localNetworkPermissionDenied,
            action: LoginFocusAction(
              onActivate: onRequestPermission,
              child: OutlinedButton.icon(
                onPressed: onRequestPermission,
                icon: const Icon(IconsaxPlusLinear.lock_1),
                label: Text(localized.requestPermission),
              ),
            ),
          );
        }
        return LoginStatusBlock(
          key: const Key('login.discovery.error'),
          icon: IconsaxPlusLinear.warning_2,
          title: localized.discoveryFailed,
          description: localized.discoveryFailedDescription,
          action: _RetryDiscoveryButton(onPressed: onRetryDiscovery),
        );
      },
      data: (_) {
        if (servers.isEmpty) {
          return LoginStatusBlock(
            key: const Key('login.discovery.empty'),
            icon: IconsaxPlusLinear.search_status,
            title: localized.noServersFound,
            description: savedCount == 0
                ? localized.noServersFoundDescription
                : localized.noNewServersDescription,
            action: _RetryDiscoveryButton(onPressed: onRetryDiscovery),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < servers.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.xs),
              _ServerRow(
                key: ValueKey(servers[index].address),
                server: servers[index],
                selected: selectedAddress == servers[index].address,
                connecting: connectingAddress == servers[index].address,
                disabled:
                    connecting && connectingAddress != servers[index].address,
                onTap: () => onServerSelected(servers[index]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RetryDiscoveryButton extends StatelessWidget {
  const _RetryDiscoveryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LoginFocusAction(
      onActivate: onPressed,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(IconsaxPlusLinear.refresh),
        label: Text(context.localized.retryDiscovery),
      ),
    );
  }
}

class _ServerRow extends StatefulWidget {
  const _ServerRow({
    super.key,
    required this.server,
    required this.onTap,
    this.selected = false,
    this.connecting = false,
    this.disabled = false,
    this.autofocus = false,
  });

  final DiscoveryInfo server;
  final VoidCallback onTap;
  final bool selected;
  final bool connecting;
  final bool disabled;
  final bool autofocus;

  @override
  State<_ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<_ServerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = widget.server.name.trim().isEmpty
        ? widget.server.address
        : widget.server.name;
    final canActivate = !widget.disabled && !widget.connecting;
    final motion = !MediaQuery.disableAnimationsOf(context);
    final background = widget.selected
        ? AppColors.surfaceHigh
        : _hovered
            ? AppColors.surfaceHover
            : AppColors.surface;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '$title, ${widget.server.address}',
      excludeSemantics: true,
      child: FocusRing(
        autofocus: widget.autofocus,
        onActivate: canActivate ? widget.onTap : null,
        borderRadius: AppRadii.controlBorder,
        child: MouseRegion(
          cursor: canActivate ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: canActivate ? (_) => setState(() => _hovered = true) : null,
          onExit: canActivate ? (_) => setState(() => _hovered = false) : null,
          child: AnimatedContainer(
            duration: motion ? AppDurations.hover : Duration.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadii.controlBorder,
              border: Border.all(
                color:
                    widget.selected ? AppColors.borderStrong : AppColors.border,
                width: AppLoginLayout.statusBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppLoginLayout.leadingBox,
                  height: AppLoginLayout.leadingBox,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: AppRadii.cardBorder,
                  ),
                  child: const Icon(
                    IconsaxPlusBold.driver,
                    size: AppLoginLayout.leadingIcon,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.server.address,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (widget.connecting)
                  const SizedBox.square(
                    dimension: AppLoginLayout.spinner,
                    child: CircularProgressIndicator(
                      strokeWidth: AppLoginLayout.progressStroke,
                      strokeCap: StrokeCap.round,
                    ),
                  )
                else
                  Icon(
                    widget.selected
                        ? IconsaxPlusBold.tick_circle
                        : IconsaxPlusLinear.arrow_right_3,
                    size: AppLoginLayout.trailingIcon,
                    color: widget.selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
