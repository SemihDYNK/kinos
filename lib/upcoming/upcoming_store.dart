import 'dart:convert';

import 'package:kinos/models/syncing/database_item.dart';

import 'upcoming_models.dart';

/// Réglages de la page « Prochainement », par profil.
class UpcomingSettings {
  const UpcomingSettings(
      {this.enabled = false, required this.region, this.byMonth = false});

  /// Masquée par défaut.
  final bool enabled;

  /// Code pays ISO (« FR »).
  final String region;

  /// Découpage de la frise : à la semaine (défaut) ou au mois.
  final bool byMonth;

  UpcomingSettings copyWith({bool? enabled, String? region, bool? byMonth}) =>
      UpcomingSettings(
          enabled: enabled ?? this.enabled,
          region: region ?? this.region,
          byMonth: byMonth ?? this.byMonth);
}

/// Dernière frise calculée, et ce dont elle dépend.
class UpcomingCache {
  const UpcomingCache(
      {required this.at, required this.signature, required this.entries});
  final DateTime at;

  /// Région et suivis au moment du calcul : la frise est refaite s'ils
  /// changent.
  final String signature;
  final List<UpcomingEntry> entries;
}

/// Persistance dans la table `Settings`, une portée par profil Kinos.
class UpcomingStore {
  UpcomingStore(this.db, String profileScope)
      : scope = '$profileScope:upcoming:v1';
  final AppDatabase db;
  final String scope;

  Future<Object?> _json(String key) async {
    final row = await db.getSetting(key, scope: scope);
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _put(String key, Object value) =>
      db.setSetting(key, jsonEncode(value), scope: scope);

  Future<UpcomingSettings> settings({required String defaultRegion}) async {
    final json = await _json('settings');
    if (json is! Map) return UpcomingSettings(region: defaultRegion);
    final region = json['r'];
    return UpcomingSettings(
        enabled: json['e'] == true,
        region: region is String && RegExp(r'^[A-Z]{2}$').hasMatch(region)
            ? region
            : defaultRegion,
        byMonth: json['m'] == true);
  }

  Future<void> saveSettings(UpcomingSettings settings) => _put('settings', {
        'e': settings.enabled,
        'r': settings.region,
        'm': settings.byMonth,
      });

  Future<List<UpcomingFollow>> follows() async {
    final json = await _json('follows');
    if (json is! List) return const [];
    return json.map(UpcomingFollow.fromJson).nonNulls.toList();
  }

  Future<void> saveFollows(List<UpcomingFollow> follows) =>
      _put('follows', [for (final f in follows) f.toJson()]);

  Future<UpcomingCache?> cache() async {
    final json = await _json('cache');
    if (json is! Map || json['t'] is! int || json['s'] is! String) return null;
    return UpcomingCache(
        at: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        signature: json['s'] as String,
        entries: [
          if (json['e'] is List)
            ...(json['e'] as List).map(UpcomingEntry.fromJson).nonNulls
        ]);
  }

  Future<void> saveCache(UpcomingCache cache) => _put('cache', {
        't': cache.at.millisecondsSinceEpoch,
        's': cache.signature,
        'e': [for (final e in cache.entries) e.toJson()],
      });
}
