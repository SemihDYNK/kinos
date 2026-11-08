import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteSubtitleServiceProvider =
    Provider((ref) => RemoteSubtitleService(ref.read(jellyApiProvider)));

bool isRemoteSubtitleDownloadStatus(int statusCode) =>
    statusCode >= 200 && statusCode < 300;

class RemoteSubtitleService {
  const RemoteSubtitleService(this._api);

  final JellyService _api;

  Future<List<RemoteSubtitleInfo>> search(
      String itemId, String language) async {
    final response = await _api.itemsItemIdRemoteSearchSubtitlesLanguageGet(
      itemId: itemId,
      language: language,
    );
    return response.body ?? const [];
  }

  Future<void> download(String itemId, String subtitleId) async {
    final statusCode = await _api.downloadRemoteSubtitle(
      itemId: itemId,
      subtitleId: subtitleId,
    );
    if (!isRemoteSubtitleDownloadStatus(statusCode)) {
      throw StateError('Le serveur a refusé le téléchargement du sous-titre.');
    }
  }
}
