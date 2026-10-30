import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

List<Widget> settingsListGroup(
    BuildContext context, Widget? label, List<Widget> children) {
  if (children.isEmpty) return const [];
  return [
    if (label != null) SettingsListGroupTitle(label: label),
    DecoratedBox(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.controlBorder,
          border: Border.all(color: AppColors.border)),
      child: ClipRRect(
          borderRadius: AppRadii.controlBorder,
          child: Column(children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 0, color: AppColors.border),
              children[index],
            ],
          ])),
    ),
    const SizedBox(height: AppSpacing.lg),
  ];
}

class SettingsListGroupTitle extends StatelessWidget {
  final Widget? label;
  const SettingsListGroupTitle({
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: label,
    );
  }
}

class SettingsListChild extends StatelessWidget {
  final Widget child;
  final bool isFirst;
  final bool isLast;
  const SettingsListChild(
      {required this.child,
      this.isFirst = false,
      this.isLast = false,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top:
                isFirst ? const Radius.circular(AppRadii.control) : Radius.zero,
            bottom:
                isLast ? const Radius.circular(AppRadii.control) : Radius.zero,
          )),
      child: child,
    );
  }
}
