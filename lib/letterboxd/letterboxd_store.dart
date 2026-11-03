import 'dart:convert';
import 'dart:isolate';
import 'package:kinos/models/syncing/database_item.dart';
import 'letterboxd_model.dart';

class LetterboxdCancelled implements Exception {
  const LetterboxdCancelled();
}

String letterboxdProfileScope(
    {required String serverId, required String url, required String userId}) {
  final parsed = Uri.tryParse(url);
  return 'letterboxd:v1:${jsonEncode([
        serverId.isNotEmpty
            ? serverId
            : parsed
                    ?.replace(userInfo: '', query: '', fragment: '')
                    .toString() ??
                '',
        userId
      ])}';
}

LetterboxdSnapshot _decode(String? value) {
  if (value == null) return const LetterboxdSnapshot();
  try {
    if (value.length > 16 * 1024 * 1024) {
      throw const FormatException('Snapshot size');
    }
    return LetterboxdSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map));
  } catch (_) {
    throw const FormatException('Letterboxd snapshot');
  }
}

Future<LetterboxdSnapshot> _decodeOffThread(String? value) =>
    Isolate.run(() => _decode(value));
Future<String> _encodeOffThread(LetterboxdSnapshot snapshot) =>
    Isolate.run(() => jsonEncode(snapshot.toJson()));

class LetterboxdStore {
  final AppDatabase db;
  final String scope;
  LetterboxdStore(this.db, this.scope);
  Future<LetterboxdSnapshot> read() async {
    final value = (await db.getSetting('snapshot', scope: scope))?.value;
    return _decodeOffThread(value);
  }

  Stream<LetterboxdSnapshot> watch() => db
      .getSettingsForScope(scope)
      .watch()
      .map((rows) =>
          rows.where((row) => row.key == 'snapshot').firstOrNull?.value)
      // Other Settings writes must not decode the same import and restart scoring.
      .distinct()
      .asyncMap(_decodeOffThread);
  Future<void> save(LetterboxdSnapshot snapshot,
      {bool Function()? isCurrent}) async {
    final encoded = await _encodeOffThread(snapshot);
    if (encoded.length > 16 * 1024 * 1024) {
      throw const FormatException('Snapshot size');
    }
    await db.transaction(() async {
      if (isCurrent != null && !isCurrent()) throw const LetterboxdCancelled();
      await db.setSetting('snapshot', encoded, scope: scope);
      if (isCurrent != null && !isCurrent()) throw const LetterboxdCancelled();
    });
  }

  Future<void> clear({bool Function()? isCurrent}) =>
      save(LetterboxdSnapshot(updatedAt: DateTime.now().toUtc()),
          isCurrent: isCurrent);
}
