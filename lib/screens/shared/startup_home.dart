import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/views_provider.dart';

final startupPageReadyProvider = StateProvider<bool>((ref) => false);

// Shared by the splash and navigation so initial requests run once per profile.
final startupHomeProvider = FutureProvider<void>((ref) async {
  final connection =
      ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  if (connection.$1 == null) return;
  await Future.wait([
    ref.watch(heroItemsProvider.future),
    () async {
      await ref.read(viewsProvider.notifier).fetchViews();
      await ref.read(dashboardProvider.notifier).fetchNextUpAndResume();
    }(),
  ]);
});
