import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'letterboxd_model.dart';
import 'letterboxd_store.dart';

final letterboxdScopeProvider = Provider.autoDispose<String?>((ref) {
  final identity = ref.watch(userProvider
      .select((u) => (u?.id, u?.credentials.serverId, u?.credentials.url)));
  if (identity.$1 == null || identity.$1!.isEmpty) return null;
  return letterboxdProfileScope(
      serverId: identity.$2 ?? '',
      url: identity.$3 ?? '',
      userId: identity.$1!);
});
final _scopedSnapshotProvider = StreamProvider.autoDispose
    .family<LetterboxdSnapshot, String>((ref, scope) =>
        LetterboxdStore(ref.watch(appDatabaseProvider), scope).watch());

// A family prevents previous-account data being retained during a reload.
final letterboxdSnapshotProvider =
    Provider.autoDispose<AsyncValue<LetterboxdSnapshot>>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? const AsyncData(LetterboxdSnapshot())
      : ref.watch(_scopedSnapshotProvider(scope));
});
