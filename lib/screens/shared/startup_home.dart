import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/dashboard/genre_browse_provider.dart';
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
    // Les tuiles de genres de l'accueil : l'ouverture les attend aussi, sans
    // jamais bloquer si elles échouent (la rangée gère son propre état).
    ref
        .watch(browseGenresProvider(allCatalog).future)
        .then<void>((_) {}, onError: (_) {}),
    () async {
      await ref.read(viewsProvider.notifier).fetchViews();
      await ref.read(dashboardProvider.notifier).fetchNextUpAndResume();
    }(),
  ]);
});
