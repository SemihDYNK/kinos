import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/theme/app_theme.dart';

enum MessageType {
  info,
  warning,
  error;

  /// Seule l'icône porte la sévérité ; le fond reste neutre.
  Color get iconColor => switch (this) {
        MessageType.info => AppColors.textSecondary,
        MessageType.warning => AppColors.warning,
        MessageType.error => AppColors.error,
      };

  IconData get icon => switch (this) {
        MessageType.info => IconsaxPlusLinear.information,
        MessageType.warning => IconsaxPlusLinear.warning_2,
        MessageType.error => IconsaxPlusLinear.danger,
      };
}

/// Note explicative rattachée à un réglage, à l'intérieur de son groupe.
class SettingsMessageBox extends StatelessWidget {
  final String message;
  final MessageType messageType;
  final VoidCallback? onTap;
  const SettingsMessageBox(this.message,
      {this.messageType = MessageType.info, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(messageType.icon,
              size: AppLoginLayout.statusIcon, color: messageType.iconColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.meta)),
        ],
      ),
    );
    if (onTap != null) {
      body = FocusRing(
          onActivate: onTap,
          borderRadius: AppRadii.controlBorder,
          child: ExcludeFocus(child: body));
    }
    return SizedBox(width: double.infinity, child: body);
  }
}
