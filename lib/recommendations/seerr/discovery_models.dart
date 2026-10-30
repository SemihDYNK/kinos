import 'dart:convert';

import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/adapters/franchise_key.dart';
import 'package:kinos/recommendations/models/trait.dart';

/// Identity is always typed: TMDB movie 42 is not TV 42.
typedef DiscoveryKey = ({String type, int id});

extension DiscoveryKeyId on DiscoveryKey {
  String get identity => 'tmdb:$type:$id';
}

typedef DiscoveryScope = ({
  String serverId,
  String userId,
  String seerrUrl,
  String language,
  int cacheDays,
});

extension DiscoveryScopeCache on DiscoveryScope {
  String get cacheScope => jsonEncode([
        serverId,
        userId,
        // Never persist credentials embedded in a URL.
        Uri.parse(seerrUrl)
            .replace(userInfo: '', query: '', fragment: '')
            .toString(),
        language,
      ]);
}

/// Canonical aliases shared by the discovery history and candidates only.
/// Names (cast, crew, keywords) keep the existing engine normalization.
TraitKey discoveryTrait(TraitKey input) {
  if (input.kind != TraitKind.genre) return input;
  const aliases = {
    'science-fiction': 'science fiction',
    'sci-fi': 'science fiction',
    'sci-fi & fantasy': 'science fiction & fantasy',
    'aventure': 'adventure',
    'comédie': 'comedy',
    'drame': 'drama',
    'documentaire': 'documentary',
    'familial': 'family',
    'fantastique': 'fantasy',
    'histoire': 'history',
    'horreur': 'horror',
    'musique': 'music',
    'mystère': 'mystery',
    'guerre': 'war',
    'téléfilm': 'tv movie',
  };
  return (kind: input.kind, value: aliases[input.value] ?? input.value);
}

List<Map<String, dynamic>> objects(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

/// Conservative: an existing media record may be a declined/old request.
/// Do not advertise it as a new discovery, including unknown future statuses.
bool knownToSeerr(Map<String, dynamic> json) {
  final info = json['mediaInfo'];
  if (info == null) return false;
  if (info is! Map<String, dynamic>) throw const FormatException('mediaInfo');
  return info.isNotEmpty;
}

class DiscoveryItem {
  final DiscoveryKey key;
  final String title;
  final String? posterPath;
  final int? year;
  final String? tvdbId;
  final String? imdbId;
  final List<TraitKey> traits;
  final List<String> franchiseKeys;

  const DiscoveryItem(
      {required this.key,
      required this.title,
      this.posterPath,
      this.year,
      this.tvdbId,
      this.imdbId,
      required this.traits,
      this.franchiseKeys = const []});

  CandidateItem get candidate => CandidateItem(
        id: key.identity,
        title: title,
        traits: traits,
        source: CandidateSource.seerrDiscovery,
        year: year,
        franchiseKeys: franchiseKeys,
      );

  factory DiscoveryItem.fromDetails(
      DiscoveryKey key, Map<String, dynamic> json) {
    if (json['id'] != key.id) {
      throw const FormatException('Mismatched detail id');
    }
    final title = json[key.type == 'movie' ? 'title' : 'name'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Missing title');
    }
    final traits = <TraitKey>{};
    void add(TraitKind kind, dynamic name) {
      if (name is String && name.trim().isNotEmpty) {
        traits.add(discoveryTrait(trait(kind, name)));
      }
    }

    for (final genre in objects(json['genres'])) {
      add(TraitKind.genre, genre['name']);
    }
    for (final keyword in objects(json['keywords'])) {
      add(TraitKind.keyword, keyword['name']);
    }
    for (final studio in objects(json['productionCompanies'])) {
      add(TraitKind.studio, studio['name']);
    }
    final credits = json['credits'] as Map<String, dynamic>? ?? const {};
    final cast = objects(credits['cast']);
    cast.sort((a, b) =>
        ((a['order'] as num?) ?? 999).compareTo((b['order'] as num?) ?? 999));
    for (final actor in cast.take(4)) {
      add(TraitKind.actor, actor['name']);
    }
    for (final crew in objects(credits['crew'])) {
      if (crew['job'] == 'Director') add(TraitKind.director, crew['name']);
    }
    final date =
        json[key.type == 'movie' ? 'releaseDate' : 'firstAirDate'] as String?;
    final year = date == null ? null : int.tryParse(date.split('-').first);
    final decade = decadeTrait(year);
    if (decade != null) traits.add(decade);
    final external = json['externalIds'] as Map<String, dynamic>? ?? const {};
    final collection = json['collection'] as Map<String, dynamic>?;
    final path = json['posterPath'] as String?;
    return DiscoveryItem(
      key: key, title: title, year: year,
      // Only TMDB relative paths are retained; never persist arbitrary URLs.
      posterPath: path != null && path.startsWith('/') && !path.startsWith('//')
          ? path
          : null,
      tvdbId: external['tvdbId']?.toString(),
      imdbId: external['imdbId'] as String?,
      traits: traits.toList(),
      franchiseKeys: franchiseKeysFor(title, traits.toList(),
          tmdbCollectionId: collection?['id']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'type': key.type,
        'id': key.id,
        'title': title,
        'posterPath': posterPath,
        'year': year,
        'tvdbId': tvdbId,
        'imdbId': imdbId,
        'traits': [
          for (final t in traits) {'kind': t.kind.name, 'value': t.value}
        ],
        'franchises': franchiseKeys,
      };
  factory DiscoveryItem.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Cache version');
    return DiscoveryItem(
      key: (type: json['type'] as String, id: json['id'] as int),
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      year: json['year'] as int?,
      tvdbId: json['tvdbId'] as String?,
      imdbId: json['imdbId'] as String?,
      traits: [
        for (final t in objects(json['traits']))
          (
            kind: TraitKind.values.byName(t['kind'] as String),
            value: t['value'] as String
          )
      ],
      franchiseKeys: List<String>.from(json['franchises'] as List),
    );
  }
}
