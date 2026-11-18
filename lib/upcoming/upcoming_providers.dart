import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart'
    show letterboxdDiscoveryClient;
import 'package:kinos/letterboxd/letterboxd_providers.dart'
    show letterboxdScopeProvider;
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';

import 'upcoming_models.dart';
import 'upcoming_source.dart';
import 'upcoming_store.dart';

final _log = Logger('Upcoming');

/// Âge maximal de la frise avant un nouveau calcul.
const upcomingRefresh = Duration(hours: 24);

/// Région par défaut : le pays de la langue de l'interface.
String defaultUpcomingRegion(Locale locale) {
  final country = locale.countryCode;
  if (country != null && RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
    return country;
  }
  return switch (locale.languageCode) {
    'fr' => 'FR',
    'de' => 'DE',
    'es' => 'ES',
    'it' => 'IT',
    'nl' => 'NL',
    'pt' => 'PT',
    'ja' => 'JP',
    'ko' => 'KR',
    'zh' => 'CN',
    'pl' => 'PL',
    'sv' => 'SE',
    'da' => 'DK',
    'tr' => 'TR',
    _ => 'US',
  };
}

Locale _appLocale(Ref ref) =>
    ref.read(clientSettingsProvider).selectedLocale ??
    WidgetsBinding.instance.platformDispatcher.locale;

class UpcomingState {
  const UpcomingState(
      {this.loaded = false,
      this.settings,
      this.follows = const [],
      this.entries,
      this.refreshing = false,
      this.failed = false,
      this.at});

  /// Réglages et suivis lus.
  final bool loaded;
  final UpcomingSettings? settings;
  final List<UpcomingFollow> follows;

  /// La frise, null tant qu'aucune n'a été calculée.
  final List<UpcomingEntry>? entries;
  final bool refreshing;

  /// Le dernier calcul a échoué (Seerr injoignable).
  final bool failed;
  final DateTime? at;

  bool get enabled => settings?.enabled ?? false;

  bool isFollowed(String key) => follows.any((f) => f.key == key);

  UpcomingState copyWith(
          {UpcomingSettings? settings,
          List<UpcomingFollow>? follows,
          List<UpcomingEntry>? entries,
          bool? refreshing,
          bool? failed,
          DateTime? at}) =>
      UpcomingState(
          loaded: true,
          settings: settings ?? this.settings,
          follows: follows ?? this.follows,
          entries: entries ?? this.entries,
          refreshing: refreshing ?? this.refreshing,
          failed: failed ?? this.failed,
          at: at ?? this.at);
}

final upcomingStoreProvider = Provider.autoDispose<UpcomingStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : UpcomingStore(ref.watch(appDatabaseProvider),
          scope.replaceFirst('letterboxd:', 'kinos:'));
});

/// Réglages, suivis et frise du profil actif. Gardé en vie : un calcul
/// continue quand on quitte la page.
final upcomingProvider =
    StateNotifierProvider.autoDispose<UpcomingController, UpcomingState>((ref) {
  ref.keepAlive();
  return UpcomingController(ref, ref.watch(upcomingStoreProvider));
});

/// La page est activée et Seerr est relié : l'entrée de la barre latérale
/// existe.
final upcomingAvailableProvider = Provider.autoDispose<bool>((ref) =>
    ref.watch(upcomingProvider.select((s) => s.enabled)) &&
    ref.watch(userProvider
        .select((u) => u?.seerrCredentials?.isConfigured ?? false)));

class UpcomingController extends StateNotifier<UpcomingState> {
  UpcomingController(this.ref, this.store) : super(const UpcomingState()) {
    _ready = _load();
  }

  final Ref ref;
  final UpcomingStore? store;
  late final Future<void> _ready;
  int _generation = 0;
  Timer? _debounce;

  Future<void> get ready => _ready;

  Future<void> _load() async {
    final store = this.store;
    if (store == null) {
      if (mounted) {
        state = UpcomingState(
            loaded: true,
            settings: UpcomingSettings(
                region: defaultUpcomingRegion(_appLocale(ref))));
      }
      return;
    }
    final settings = await store.settings(
        defaultRegion: defaultUpcomingRegion(_appLocale(ref)));
    final follows = await store.follows();
    final cache = await store.cache();
    if (!mounted) return;
    state = UpcomingState(
        loaded: true,
        settings: settings,
        follows: follows,
        entries: cache?.entries,
        at: cache?.at);
  }

  String _signature(UpcomingSettings settings, List<UpcomingFollow> follows) =>
      [
        // Version du calcul : une frise d'une version précédente est
        // refaite.
        'v2',
        settings.region,
        _appLocale(ref).languageCode,
        ...([for (final f in follows) f.key]..sort()),
      ].join('|');

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _saveSettings(UpcomingSettings settings) async {
    await _ready;
    if (!mounted) return;
    state = state.copyWith(settings: settings);
    await store?.saveSettings(settings);
  }

  Future<void> setEnabled(bool enabled) async {
    await _ready;
    final settings = state.settings;
    if (settings != null) {
      await _saveSettings(settings.copyWith(enabled: enabled));
    }
  }

  Future<void> setRegion(String region) async {
    await _ready;
    final settings = state.settings;
    if (settings == null || settings.region == region) return;
    await _saveSettings(settings.copyWith(region: region));
    _scheduleRefresh();
  }

  Future<void> setByMonth(bool byMonth) async {
    await _ready;
    final settings = state.settings;
    if (settings != null) {
      await _saveSettings(settings.copyWith(byMonth: byMonth));
    }
  }

  /// Suit [follow], ou arrête de le suivre s'il l'est déjà.
  Future<void> toggleFollow(UpcomingFollow follow) async {
    await _ready;
    if (!mounted) return;
    final follows = state.isFollowed(follow.key)
        ? [
            for (final f in state.follows)
              if (f.key != follow.key) f
          ]
        : [...state.follows, follow];
    state = state.copyWith(follows: follows);
    await store?.saveFollows(follows);
    _scheduleRefresh();
  }

  Future<void> unfollow(String key) async {
    await _ready;
    final follow = state.follows.where((f) => f.key == key).firstOrNull;
    if (follow != null) await toggleFollow(follow);
  }

  // Plusieurs suivis d'affilée (la fenêtre « Suivre… ») : un seul calcul.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => refresh(force: true));
  }

  /// Recalcule la frise si elle est trop ancienne, si la région ou les
  /// suivis ont changé (ou toujours, si [force]).
  Future<void> refresh({bool force = false}) async {
    await _ready;
    final settings = state.settings;
    final store = this.store;
    if (!mounted || settings == null || store == null || state.refreshing) {
      return;
    }
    final credentials = ref.read(userProvider)?.seerrCredentials;
    final signature = _signature(settings, state.follows);
    if (!force) {
      final cache = await store.cache();
      if (cache != null &&
          cache.signature == signature &&
          DateTime.now().difference(cache.at) < upcomingRefresh) {
        return;
      }
    }
    final client = letterboxdDiscoveryClient(credentials,
        interval: const Duration(milliseconds: 120), concurrency: 4);
    if (client == null || !mounted) return;
    final generation = ++_generation;
    state = state.copyWith(refreshing: true);
    final language = _appLocale(ref).languageCode;
    try {
      final now = DateTime.now();
      final entries = await UpcomingSource(
              (path, {query = const {}}) =>
                  // Sur les listes `discover`, Seerr prend `language`
                  // pour la langue d'origine : seuls les films français
                  // restaient. Les fiches, elles, le prennent pour la
                  // langue d'affichage.
                  client.get(path,
                      query: query,
                      language: path.startsWith('discover/') ? null : language),
              map: client.map,
              region: settings.region,
              today: now)
          .load(state.follows,
              failed: (f) => _log.warning('Suivi illisible : ${f.key}'));
      _log.info('Frise : ${entries.length} titres, '
          '${state.follows.length} suivis, région ${settings.region}');
      if (!mounted || generation != _generation) return;
      await store.saveCache(
          UpcomingCache(at: now, signature: signature, entries: entries));
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
          entries: entries, at: now, refreshing: false, failed: false);
    } catch (error) {
      _log.warning('Frise impossible à calculer : $error');
      if (mounted && generation == _generation) {
        state = state.copyWith(refreshing: false, failed: true);
      }
    } finally {
      client.close();
    }
  }
}
