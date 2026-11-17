import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cache des jaquettes et bandeaux.
///
/// Par défaut, flutter_cache_manager range ses fichiers dans le dossier
/// temporaire : sous Linux c'est `/tmp`, un tmpfs vidé à chaque démarrage
/// de la machine. Le premier lancement de Kinos après un redémarrage
/// retéléchargeait alors toutes les images (et le serveur devait souvent
/// les redimensionner à nouveau), avec le rideau de démarrage qui attend le
/// bandeau. Les fichiers vont donc dans le dossier de cache de l'app
/// (`~/.cache/app.kinos` sous Linux), qui survit au redémarrage.
///
/// Les images sont indexées par leur étiquette serveur : une affiche
/// modifiée change de clé, une longue durée de conservation ne sert jamais
/// une image périmée.
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(kIsWeb
      ? Config(key,
          stalePeriod: _stalePeriod,
          maxNrOfCacheObjects: _maxObjects,
          fileService: HttpFileService())
      : Config(key,
          stalePeriod: _stalePeriod,
          maxNrOfCacheObjects: _maxObjects,
          fileSystem: _PersistentFileSystem(key),
          fileService: HttpFileService()));

  static const _stalePeriod = Duration(days: 30);

  // Un accueil complet (bandeau, reprises, genres, rangées) dépasse déjà
  // les 256 images de l'ancienne limite.
  static const _maxObjects = 1500;
}

class _PersistentFileSystem implements FileSystem {
  _PersistentFileSystem(String key) : _directory = _create(key);
  final Future<Directory> _directory;

  static Future<Directory> _create(String key) async {
    final base = await getApplicationCacheDirectory();
    final directory = const LocalFileSystem().directory(p.join(base.path, key));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await _directory;
    // Vidé à la main pendant que l'app tourne : on le recrée.
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory.childFile(name);
  }
}
