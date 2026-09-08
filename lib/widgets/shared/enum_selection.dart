import 'package:flutter/material.dart';

import 'package:fladder/util/focus_provider.dart';
import 'package:fladder/util/position_provider.dart';
import 'package:fladder/widgets/shared/anchored_popover.dart';
import 'package:fladder/widgets/shared/ensure_visible.dart';
import 'package:fladder/widgets/shared/item_actions.dart';

class EnumBox<T> extends StatefulWidget {
  final String? current;
  final Widget? currentWidget;
  final bool autoFocus;
  final List<ItemAction> Function(BuildContext context) itemBuilder;
  final Function(bool focused)? onFocusChanged;

  const EnumBox({
    this.current,
    this.currentWidget,
    this.autoFocus = false,
    required this.itemBuilder,
    this.onFocusChanged,
    super.key,
  }) : assert(current != null || currentWidget != null,
            "At least one of 'current' or 'currentWidget' must be provided");

  @override
  State<EnumBox<T>> createState() => _EnumBoxState<T>();
}

class _EnumBoxState<T> extends State<EnumBox<T>> {
  // Champ d'état : le popover doit rester rattaché au même contrôleur si ce
  // widget se reconstruit (ex. valeur courante changée ailleurs) pendant
  // qu'il est ouvert.
  final _controller = AnchoredPopoverController();

  List<PopoverOption> _options(List<ItemAction> items) {
    return items.whereType<ItemActionButton>().map((item) {
      return PopoverOption(
        content: item.label ?? const SizedBox.shrink(),
        selected: item.selected,
        onSelect: () => item.action?.call(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final itemList = widget.itemBuilder(context);

    final foreGroundColor = Theme.of(context).colorScheme.onPrimaryContainer;

    final hasMultipleItems = itemList.length > 1;

    final labelWidget = Padding(
      padding: padding,
      child: Material(
        textStyle: textStyle?.copyWith(
            fontWeight: FontWeight.bold, color: foreGroundColor),
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: widget.currentWidget != null
                  ? DefaultTextStyle.merge(
                      style: textStyle?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: foreGroundColor,
                      ),
                      child: widget.currentWidget!,
                    )
                  : Text(widget.current ?? "", textAlign: TextAlign.start),
            ),
            const SizedBox(width: 6),
            if (itemList.length > 1)
              Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )
          ],
        ),
      ),
    );
    final position = PositionProvider.of(context);
    final borderRadius = BorderRadius.horizontal(
      left: position == null || position == PositionContext.first
          ? const Radius.circular(16)
          : const Radius.circular(4),
      right: position == null || position == PositionContext.last
          ? const Radius.circular(16)
          : const Radius.circular(4),
    );
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withAlpha(hasMultipleItems ? 255 : 100),
        borderRadius: borderRadius,
        border: BoxBorder.all(
          color: Theme.of(context).colorScheme.primaryContainer,
          strokeAlign: BorderSide.strokeAlignInside,
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnchoredPopover(
        controller: _controller,
        popoverBuilder: (context, close) => PopoverOptionList(
          onSelected: close,
          options: _options(itemList),
        ),
        child: FocusButton(
          child: labelWidget,
          darkOverlay: false,
          autoFocus: widget.autoFocus,
          borderRadius: borderRadius,
          onFocusChanged: widget.onFocusChanged ??
              (value) {
                if (value) {
                  context.ensureVisible();
                }
              },
          onTap: hasMultipleItems ? _controller.toggle : null,
        ),
      ),
    );
  }
}

class EnumSelection<T> extends StatelessWidget {
  final Widget label;
  final String current;
  final Widget? currentWidget;
  final List<ItemAction> Function(BuildContext context) itemBuilder;
  const EnumSelection({
    super.key,
    required this.label,
    required this.current,
    this.currentWidget,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      textStyle: Theme.of(context).textTheme.titleMedium,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          runAlignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.titleMedium,
              child: label,
            ),
            EnumBox(
                current: current,
                currentWidget: currentWidget,
                itemBuilder: itemBuilder),
          ].toList(),
        ),
      ),
    );
  }
}
