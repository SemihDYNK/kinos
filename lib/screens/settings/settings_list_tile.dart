import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/widgets/shared/enum_selection.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';

class SettingsListTileCheckbox extends StatelessWidget {
  final Widget label;
  final Widget? subLabel;
  final Function(bool?)? onChanged;
  final bool value;
  const SettingsListTileCheckbox({
    required this.label,
    this.subLabel,
    this.onChanged,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      label: label,
      subLabel: subLabel,
      onTap: onChanged != null
          ? () {
              onChanged!(!value);
            }
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsListTileEnum extends StatelessWidget {
  final Widget label;
  final Widget? subLabel;
  final String? current;
  final Widget? currentWidget;
  final List<ItemAction> Function(BuildContext context) itemBuilder;
  final bool selected;
  final bool autoFocus;
  final IconData? icon;
  final Widget? leading;
  final bool trailingInlineWithLabel;
  final Color? contentColor;

  const SettingsListTileEnum({
    required this.label,
    this.subLabel,
    this.current,
    this.currentWidget,
    required this.itemBuilder,
    this.selected = false,
    this.autoFocus = false,
    this.icon,
    this.leading,
    this.trailingInlineWithLabel = false,
    this.contentColor,
    super.key,
  }) : assert(
          current != null || currentWidget != null,
          "At least one of 'current' or 'currentWidget' must be provided",
        );

  @override
  Widget build(BuildContext context) {
    final itemList = itemBuilder(context);
    final useBottomSheet =
        AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad;
    final hasMultipleItems = itemList.length > 1;

    void openSelectionSheet() {
      if (!hasMultipleItems) return;
      showBottomSheetPill(
        context: context,
        content: (context, scrollController) => ListView(
          shrinkWrap: true,
          controller: scrollController,
          children: [
            const SizedBox(height: 6),
            ...itemList.map((e) => e.toListItem(context)),
          ],
        ),
      );
    }

    return SettingsListTile(
      label: label,
      subLabel: subLabel,
      selected: selected,
      autoFocus: autoFocus,
      icon: icon,
      leading: leading,
      trailingInlineWithLabel: trailingInlineWithLabel,
      contentColor: contentColor,
      onTap: useBottomSheet ? openSelectionSheet : null,
      trailing: EnumBox(
        current: current,
        currentWidget: currentWidget,
        autoFocus: autoFocus,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  final Widget label;
  final Widget? subLabel;
  final Widget? trailing;
  final bool selected;
  final bool autoFocus;
  final IconData? icon;
  final Widget? leading;
  final bool trailingInlineWithLabel;
  final bool navigation;
  final bool valueAsTrailing;
  final Color? contentColor;
  final VoidCallback? onTap;
  const SettingsListTile({
    required this.label,
    this.subLabel,
    this.trailing,
    this.selected = false,
    this.autoFocus = false,
    this.leading,
    this.icon,
    this.trailingInlineWithLabel = false,
    this.navigation = false,
    this.valueAsTrailing = false,
    this.contentColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = contentColor ?? AppColors.textPrimary;
    final value = trailing ?? (valueAsTrailing ? subLabel : null);
    final description = navigation || valueAsTrailing ? null : subLabel;
    final leadingWidget = leading ?? (icon == null ? null : Icon(icon));
    Widget body = LayoutBuilder(
        builder: (context, constraints) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: (navigation
                            ? AppPageLayout.toolbarHeight
                            : AppPageLayout.rowHeight) -
                        AppSpacing.md -
                        (onTap == null ? 0 : FocusRing.boxInset(context))),
                child: Row(children: [
                  if (leadingWidget != null) ...[
                    IconTheme(
                        data: IconThemeData(color: foreground),
                        child: leadingWidget),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        DefaultTextStyle.merge(
                            style: AppTypography.cardTitle
                                .copyWith(color: foreground),
                            child: label),
                        if (description != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          DefaultTextStyle.merge(
                              style: AppTypography.meta.copyWith(
                                  color:
                                      contentColor ?? AppColors.textSecondary),
                              child: description),
                        ],
                      ])),
                  if (value != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * .45 <
                                    AppManagementLayout.settingsValueWidth
                                ? constraints.maxWidth * .45
                                : AppManagementLayout.settingsValueWidth),
                        child: DefaultTextStyle.merge(
                            style: AppTypography.cardTitle
                                .copyWith(color: foreground),
                            child: value)),
                  ],
                  if (onTap != null && valueAsTrailing) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ]),
              ),
            ));
    if (onTap != null) {
      body = FocusRing(
          onActivate: onTap,
          autofocus: autoFocus,
          borderRadius: AppRadii.controlBorder,
          child: ExcludeFocus(child: body));
    }
    return DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: AppRadii.controlBorder,
          border: selected ? Border.all(color: AppColors.borderStrong) : null,
        ),
        child: body);
  }
}
