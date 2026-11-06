import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

/// Contexte du serveur retenu, rappelé au-dessus du formulaire.
class LoginServerSummary extends StatelessWidget {
  const LoginServerSummary({
    required this.name,
    required this.address,
    super.key,
  });

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.controlBorder,
        border: Border.all(
          color: AppColors.border,
          width: AppLoginLayout.statusBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusBold.driver,
            size: AppLoginLayout.leadingIcon,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    address,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Méthodes de connexion alternatives au formulaire.
///
/// Le lien d'authentification est l'action primaire de ce groupe (blanc
/// plein) ; le code de connexion rapide reste secondaire (contour). L'ordre
/// visuel et l'ordre de tabulation sont identiques.
class LoginAlternateMethods extends StatelessWidget {
  const LoginAlternateMethods({
    required this.onAuthLink,
    this.onQuickConnect,
    this.onAdvanced,
    super.key,
  });

  final VoidCallback onAuthLink;
  final VoidCallback? onQuickConnect;
  final VoidCallback? onAdvanced;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                context.localized.loginOtherMethods,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LoginFocusAction(
          onActivate: onAuthLink,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('login.authLink'),
              onPressed: onAuthLink,
              icon: const Icon(IconsaxPlusBold.link_square),
              label: Text(context.localized.connectWithAuthLink),
            ),
          ),
        ),
        if (onQuickConnect != null) ...[
          const SizedBox(height: AppSpacing.sm),
          LoginFocusAction(
            onActivate: onQuickConnect,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('login.quickConnect'),
                onPressed: onQuickConnect,
                icon: const Icon(IconsaxPlusBold.scan_barcode),
                label: Text(context.localized.quickConnectLoginUsingCode),
              ),
            ),
          ),
        ],
        if (onAdvanced != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: LoginFocusAction(
              onActivate: onAdvanced,
              child: TextButton.icon(
                key: const Key('login.advanced'),
                onPressed: onAdvanced,
                icon: const Icon(IconsaxPlusLinear.setting_3),
                label: Text(context.localized.advanced),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
