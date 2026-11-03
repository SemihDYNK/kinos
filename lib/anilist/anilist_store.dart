import 'dart:convert';
import 'package:kinos/models/syncing/database_item.dart';
import 'mapping.dart';

String anilistProfileScope(
    {required String serverId, required String url, required String userId}) {
  final parsed = Uri.tryParse(url);
  final server = serverId.isNotEmpty
      ? serverId
      : parsed?.replace(userInfo: '', query: '', fragment: '').toString() ?? '';
  return 'anilist:v1:${jsonEncode([server, userId])}';
}

class AnilistScopeChanged implements Exception {
  const AnilistScopeChanged();
}

class SavedAnilistLink {
  final int id;
  final bool confirmed;
  const SavedAnilistLink(this.id, this.confirmed);
}

class AnilistStore {
  final AppDatabase db;
  final String scope;
  AnilistStore(this.db, this.scope);
  Future<SavedAnilistLink?> read(AnilistTarget target) async {
    final row = await db.getSetting(target.identity, scope: scope);
    if (row == null) return null;
    try {
      final data = jsonDecode(row.value);
      if (data is! Map) return null;
      final id = positiveId(data['id']);
      if (id == null) return null;
      return SavedAnilistLink(id, data['fingerprint'] == target.fingerprint);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(AnilistTarget target, int id,
      {bool Function()? isCurrent}) async {
    if (id <= 0) throw ArgumentError.value(id);
    await db.transaction(() async {
      if (isCurrent != null && !isCurrent()) throw const AnilistScopeChanged();
      await db.setSetting(target.identity,
          jsonEncode({'id': id, 'fingerprint': target.fingerprint}),
          scope: scope);
      if (isCurrent != null && !isCurrent()) throw const AnilistScopeChanged();
    });
  }

  Future<void> remove(AnilistTarget target,
      {bool Function()? isCurrent}) async {
    await db.transaction(() async {
      if (isCurrent != null && !isCurrent()) throw const AnilistScopeChanged();
      await db.deleteSetting(target.identity, scope: scope);
      if (isCurrent != null && !isCurrent()) throw const AnilistScopeChanged();
    });
  }
}
