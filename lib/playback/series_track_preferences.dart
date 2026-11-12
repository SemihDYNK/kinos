import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/widgets/shared/track_label.dart';

/// Langues audio et sous-titres retenues pour une série, par profil.
///
/// Kinos ne retient sinon la piste que d'un épisode au suivant dans une même
/// session : au lancement suivant, la langue par défaut du profil reprenait
/// le dessus (VF sur une série regardée en VO).
class SeriesTrackPreference {
  const SeriesTrackPreference({
    this.audioLanguage,
    this.subtitleLanguage,
    this.subtitlesOff = false,
    this.subtitleForced = false,
  });

  /// Code de langue tel que Jellyfin le donne (« jpn », « eng »…).
  final String? audioLanguage;
  final String? subtitleLanguage;
  final bool subtitlesOff;
  final bool subtitleForced;

  bool get isEmpty =>
      audioLanguage == null && subtitleLanguage == null && !subtitlesOff;

  Map<String, Object?> toJson() => {
        'version': 1,
        if (audioLanguage != null) 'audio': audioLanguage,
        if (subtitleLanguage != null) 'subtitle': subtitleLanguage,
        if (subtitlesOff) 'subtitlesOff': true,
        if (subtitleForced) 'subtitleForced': true,
      };

  static SeriesTrackPreference? fromJson(Object? json) {
    if (json is! Map || json['version'] != 1) return null;
    String? text(Object? value) =>
        value is String && value.isNotEmpty ? value : null;
    return SeriesTrackPreference(
      audioLanguage: text(json['audio']),
      subtitleLanguage: text(json['subtitle']),
      subtitlesOff: json['subtitlesOff'] == true,
      subtitleForced: json['subtitleForced'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SeriesTrackPreference &&
      other.audioLanguage == audioLanguage &&
      other.subtitleLanguage == subtitleLanguage &&
      other.subtitlesOff == subtitlesOff &&
      other.subtitleForced == subtitleForced;

  @override
  int get hashCode => Object.hash(
      audioLanguage, subtitleLanguage, subtitlesOff, subtitleForced);
}

String? _known(String? language) {
  final code = language?.trim() ?? '';
  return sameTrackLanguage(code, code) ? code : null;
}

/// Préférence à retenir d'après les pistes en cours. Une piste dont la
/// langue est inconnue ne dit rien de la langue voulue : la valeur
/// précédente est alors conservée.
SeriesTrackPreference preferenceFromStreams(
    MediaStreamsModel streams, SeriesTrackPreference? previous) {
  final audio = streams.currentAudioStream;
  final sub = streams.currentSubStream;
  final audioLanguage = (audio != null && audio.index >= 0)
      ? _known(audio.language) ?? previous?.audioLanguage
      : previous?.audioLanguage;
  if (sub == null || sub.index < 0) {
    return SeriesTrackPreference(
        audioLanguage: audioLanguage, subtitlesOff: true);
  }
  final subtitleLanguage = _known(sub.language);
  if (subtitleLanguage == null) {
    return SeriesTrackPreference(
      audioLanguage: audioLanguage,
      subtitleLanguage: previous?.subtitleLanguage,
      subtitlesOff: previous?.subtitlesOff ?? false,
      subtitleForced: previous?.subtitleForced ?? false,
    );
  }
  return SeriesTrackPreference(
    audioLanguage: audioLanguage,
    subtitleLanguage: subtitleLanguage,
    subtitleForced: sub.isForced,
  );
}

bool _isCommentary(AudioStreamModel stream) =>
    '${stream.displayTitle} ${stream.name}'.toLowerCase().contains('comment');

/// Piste audio de la langue retenue : la principale plutôt qu'un
/// commentaire, puis celle marquée par défaut, sinon la première.
int? preferredAudioIndex(
    SeriesTrackPreference pref, List<AudioStreamModel> streams) {
  final language = pref.audioLanguage;
  if (language == null) return null;
  final matches = [
    for (final stream in streams)
      if (stream.index >= 0 && sameTrackLanguage(stream.language, language))
        stream
  ];
  if (matches.isEmpty) return null;
  int rank(AudioStreamModel s) =>
      (_isCommentary(s) ? 2 : 0) + (s.isDefault ? 0 : 1);
  matches.sort((a, b) => rank(a).compareTo(rank(b)));
  return matches.first.index;
}

/// Sous-titres retenus : -1 s'ils étaient désactivés ; sinon la piste de
/// la langue retenue, forcée ou complète comme la dernière fois.
int? preferredSubIndex(
    SeriesTrackPreference pref, List<SubStreamModel> streams) {
  if (pref.subtitlesOff) return -1;
  final language = pref.subtitleLanguage;
  if (language == null) return null;
  final matches = [
    for (final stream in streams)
      if (stream.index >= 0 && sameTrackLanguage(stream.language, language))
        stream
  ];
  if (matches.isEmpty) return null;
  int rank(SubStreamModel s) =>
      (s.isForced == pref.subtitleForced ? 0 : 4) +
      (s.isHearingImpaired ? 2 : 0) +
      (s.isDefault ? 0 : 1);
  matches.sort((a, b) => rank(a).compareTo(rank(b)));
  return matches.first.index;
}

/// [streams] avec les pistes retenues pour la série sélectionnées, quand
/// l'épisode les propose ; inchangé sinon.
MediaStreamsModel applySeriesTracks(
    MediaStreamsModel streams, SeriesTrackPreference? pref) {
  if (pref == null || pref.isEmpty) return streams;
  final audio = preferredAudioIndex(pref, streams.audioStreams);
  final sub = preferredSubIndex(pref, streams.subStreams);
  if (audio == null && sub == null) return streams;
  return streams.copyWith(
      defaultAudioStreamIndex: audio, defaultSubStreamIndex: sub);
}

/// Identifiant de la série d'un épisode, null pour tout le reste.
String? seriesIdOf(ItemBaseModel item) =>
    item is EpisodeModel && (item.parentId?.isNotEmpty ?? false)
        ? item.parentId
        : null;

String? _scope(Ref ref) {
  final user = ref.read(userProvider);
  if (user == null) return null;
  return '${user.credentials.serverId}:${user.id}:series-tracks:v1';
}

/// Préférence retenue pour une série du profil actif.
final seriesTrackPreferenceProvider = FutureProvider.autoDispose
    .family<SeriesTrackPreference?, String>((ref, seriesId) async {
  ref.watch(userProvider.select((user) => (user?.id, user?.credentials)));
  return ref.read(seriesTracksProvider).read(seriesId);
});

final seriesTracksProvider = Provider<SeriesTracks>(SeriesTracks.new);

/// Lecture et écriture des langues retenues par série (table Drift
/// `Settings`, une portée par serveur et par profil).
class SeriesTracks {
  SeriesTracks(this.ref);
  final Ref ref;

  Future<SeriesTrackPreference?> read(String seriesId) async {
    final scope = _scope(ref);
    if (scope == null) return null;
    final row =
        await ref.read(appDatabaseProvider).getSetting(seriesId, scope: scope);
    if (row == null) return null;
    try {
      return SeriesTrackPreference.fromJson(jsonDecode(row.value));
    } on FormatException {
      return null;
    }
  }

  /// Retient les pistes en cours de [item] si c'est un épisode. Sans effet
  /// si rien n'a changé ; une erreur de stockage n'interrompt jamais la
  /// lecture.
  Future<void> remember(ItemBaseModel item, MediaStreamsModel? streams) async {
    final seriesId = seriesIdOf(item);
    final scope = _scope(ref);
    if (seriesId == null || streams == null || scope == null) return;
    try {
      final previous = await read(seriesId);
      final next = preferenceFromStreams(streams, previous);
      if (next == previous) return;
      if (next.isEmpty) {
        await forget(seriesId);
        return;
      }
      await ref
          .read(appDatabaseProvider)
          .setSetting(seriesId, jsonEncode(next.toJson()), scope: scope);
      ref.invalidate(seriesTrackPreferenceProvider(seriesId));
    } catch (_) {}
  }

  Future<void> forget(String seriesId) async {
    final scope = _scope(ref);
    if (scope == null) return;
    await ref.read(appDatabaseProvider).deleteSetting(seriesId, scope: scope);
    ref.invalidate(seriesTrackPreferenceProvider(seriesId));
  }

  /// Indices audio et sous-titres retenus pour l'épisode [item], ou null
  /// s'il n'y a rien à appliquer.
  Future<({int? audio, int? sub})?> defaultsFor(
      ItemBaseModel item, MediaStreamsModel? streams) async {
    final seriesId = seriesIdOf(item);
    if (seriesId == null || streams == null) return null;
    try {
      final pref = await read(seriesId);
      if (pref == null || pref.isEmpty) return null;
      final audio = preferredAudioIndex(pref, streams.audioStreams);
      final sub = preferredSubIndex(pref, streams.subStreams);
      if (audio == null && sub == null) return null;
      return (audio: audio, sub: sub);
    } catch (_) {
      return null;
    }
  }
}
