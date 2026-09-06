import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/syncing/database_item.dart';
import 'package:fladder/providers/database_provider.dart';
import 'package:fladder/theme/palette_service.dart';

/// Persiste la dominante extraite d'une jaquette dans la table Drift
/// `palette_cache`, pour ne pas refaire l'extraction à chaque apparition
/// de l'item.
class _DriftPaletteCache implements PaletteCacheStore {
  const _DriftPaletteCache(this._db);

  final AppDatabase _db;

  @override
  Future<int?> read(String itemId) async =>
      (await _db.getPalette(itemId))?.argb;

  @override
  Future<void> write(String itemId, int argb) => _db.savePalette(itemId, argb);
}

/// Instance partagée : le cache anti-doublon de [PaletteService] n'a de sens
/// que s'il n'existe qu'un seul service pour toute l'app.
final paletteServiceProvider = Provider<PaletteService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PaletteService(_DriftPaletteCache(db));
});
