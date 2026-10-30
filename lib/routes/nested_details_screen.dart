import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/items/item_details_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/media_navigation.dart';

@RoutePage()
class DetailsScreen extends ConsumerStatefulWidget {
  final String id;
  final ItemBaseModel? item;
  final Object? tag;
  const DetailsScreen({
    @QueryParam() this.id = '',
    this.item,
    this.tag,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  late Widget currentWidget = const Center(
    key: Key("progress-indicator"),
    child: CircularProgressIndicator(strokeCap: StrokeCap.round),
  );

  @override
  void didUpdateWidget(covariant DetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.item != widget.item) {
      updateWidget();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      currentWidget = widget.item!.detailScreenWidget;
    } else {
      updateWidget();
    }
  }

  Future<void> updateWidget() async {
    final requestedId = widget.id;
    Future.microtask(() async {
      if (!mounted) return;
      if (widget.item != null) {
        setState(() {
          currentWidget = widget.item!.detailScreenWidget;
        });
      } else {
        final response = await ref
            .read(itemDetailsProvider.notifier)
            .fetchDetails(widget.id);
        if (context.mounted && widget.id == requestedId) {
          if (response != null) {
            setState(() {
              currentWidget = response.detailScreenWidget;
            });
          } else {
            const DashboardRoute().navigate(context);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaNavigationScope(tag: widget.tag, child: currentWidget);
  }
}
