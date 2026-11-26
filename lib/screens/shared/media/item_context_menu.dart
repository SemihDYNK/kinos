import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

/// Les actions rapides d'un titre, sur sa tuile : clic droit, ou touche
/// Menu (Maj+F10) quand la tuile a le focus. Sans titre (tuile Arr, Seerr),
/// la tuile reste telle quelle.
class ItemContextMenuRegion extends ConsumerWidget {
  const ItemContextMenuRegion(
      {required this.item, required this.child, super.key});
  final ItemBaseModel? item;
  final Widget child;

  static const shortcuts = [
    SingleActivator(LogicalKeyboardKey.contextMenu),
    SingleActivator(LogicalKeyboardKey.f10, shift: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    if (item == null) return child;
    void atTile() {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      showItemContextMenu(
          context, ref, item, box.localToGlobal(box.size.center(Offset.zero)));
    }

    return CallbackShortcuts(
      bindings: {for (final key in shortcuts) key: atTile},
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            showItemContextMenu(context, ref, item, details.globalPosition),
        child: child,
      ),
    );
  }
}

/// Le menu d'un titre à [at] : son nom en tête, puis ses actions, regroupées
/// (lire, puis le suivi, puis le rangement, puis la gestion, et la
/// suppression à part).
Future<void> showItemContextMenu(BuildContext context, WidgetRef ref,
    ItemBaseModel item, Offset at) async {
  final actions = item.generateActions(context, ref);
  await showGlassMenu<dynamic>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    constraints: const BoxConstraints(
        minWidth: AppMenu.minWidth, maxWidth: AppMenu.maxWidth),
    items: [
      _ItemMenuHeader(item),
      ...actions.popupMenuItems(useIcons: true),
    ],
  );
}

class _ItemMenuHeader extends PopupMenuEntry<dynamic> {
  const _ItemMenuHeader(this.item);
  final ItemBaseModel item;

  @override
  double get height => AppPageLayout.toolbarHeight + AppSpacing.sm;

  @override
  bool represents(dynamic value) => false;

  @override
  State<_ItemMenuHeader> createState() => _ItemMenuHeaderState();
}

class _ItemMenuHeaderState extends State<_ItemMenuHeader> {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = widget.item.subText;
    return ExcludeFocus(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
