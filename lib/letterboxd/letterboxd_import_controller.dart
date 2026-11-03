import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'package:kinos/recommendations/seerr/discovery_client.dart';
import 'package:kinos/util/kinos_config.dart';
import 'letterboxd_model.dart';
import 'letterboxd_matching.dart';
import 'letterboxd_parser.dart';
import 'letterboxd_providers.dart';
import 'letterboxd_store.dart';

Future<List<LetterboxdFilm>> _parseExport(Uint8List bytes) =>
    Isolate.run(() => parseLetterboxdExport(bytes));

class LetterboxdImportState {
  final bool busy, ready, saved, networkWarning;
  final String? error;
  final String phase;
  final int done, total;
  final List<LetterboxdRecord> records;
  const LetterboxdImportState(
      {this.busy = false,
      this.ready = false,
      this.saved = false,
      this.networkWarning = false,
      this.error,
      this.phase = 'read',
      this.done = 0,
      this.total = 0,
      this.records = const []});
  bool get matching => busy && phase == 'match';
  int get matched =>
      records.where((r) => r.work?.traits.isNotEmpty == true).length;
}

class LetterboxdImportController extends StateNotifier<LetterboxdImportState> {
  final LetterboxdStore store;
  final Future<List<LetterboxdWork>> Function() loadLibrary;
  final bool Function() isCurrent;
  final DiscoveryClient? Function()? createClient;
  DiscoveryClient? _client;
  int _generation = 0;
  LetterboxdImportController(
      {required this.store,
      required this.loadLibrary,
      required this.isCurrent,
      this.createClient})
      : super(const LetterboxdImportState());
  bool _active(int generation) =>
      mounted && generation == _generation && isCurrent();
  void cancel() {
    _generation++;
    _client?.close();
    _client = null;
    if (mounted) state = const LetterboxdImportState();
  }

  @override
  void dispose() {
    _generation++;
    _client?.close();
    super.dispose();
  }

  Future<void> prepare(Uint8List bytes) async {
    cancel();
    final generation = _generation;
    state = const LetterboxdImportState(busy: true);
    try {
      final films = await _parseExport(bytes);
      if (_active(generation)) await _resolve(films, generation);
    } catch (_) {
      if (_active(generation)) {
        state = const LetterboxdImportState(error: 'file');
      }
    }
  }

  Future<void> retrySaved() async {
    if (state.busy) return;
    cancel();
    final generation = _generation;
    state = const LetterboxdImportState(busy: true);
    try {
      final saved = await store.read();
      if (_active(generation)) {
        await _resolve(saved.records.map((r) => r.film).toList(), generation);
      }
    } catch (_) {
      if (_active(generation)) {
        state = const LetterboxdImportState(error: 'storage');
      }
    }
  }

  Future<void> _resolve(List<LetterboxdFilm> films, int generation) async {
    state =
        LetterboxdImportState(busy: true, phase: 'match', total: films.length);
    var warning = false;
    List<LetterboxdWork> library;
    try {
      library = await loadLibrary();
    } catch (_) {
      library = [];
      warning = true;
    }
    if (!_active(generation)) return;
    LetterboxdSnapshot previous;
    try {
      previous = await store.read();
    } catch (_) {
      previous = const LetterboxdSnapshot();
    }
    if (!_active(generation)) return;
    final cached = {for (final r in previous.records) r.film.uri: r};
    final matcher = LetterboxdMatcher(library);
    final client = createClient?.call();
    _client = client;
    LetterboxdResolver? resolver =
        client == null ? null : LetterboxdResolver(client);
    final results = <LetterboxdRecord>[];
    try {
      for (var i = 0; i < films.length; i++) {
        if (!_active(generation)) return;
        final film = films[i];
        var choices = matcher.choices(film);
        LetterboxdWork? work = exactLetterboxdMatch(film, choices);
        final saved = cached[film.uri];
        if (work == null &&
            saved?.film.title == film.title &&
            saved?.film.year == film.year) {
          work = saved?.work;
        }
        if (work != null) {
          choices = [work];
        } else if (resolver != null) {
          try {
            final external = await resolver.search(film);
            if (!_active(generation)) return;
            choices = {
              for (final c in [...choices, ...external]) c.identity: c
            }.values.toList();
            final match = exactLetterboxdMatch(film, choices);
            if (match != null) {
              work = match.traits.isNotEmpty
                  ? match
                  : await resolver.details(match.tmdbId!);
              if (work.year != film.year) {
                work = null;
              }
              if (work != null) {
                choices = [
                  work,
                  ...choices.where((c) => c.identity != work!.identity)
                ];
              }
            }
          } catch (_) {
            if (!_active(generation)) return;
            warning = true;
            _client?.close();
            resolver = null;
          }
        }
        results.add(LetterboxdRecord(film, work: work, choices: choices));
        if (i % 25 == 0 || i == films.length - 1) {
          if (!_active(generation)) return;
          state = LetterboxdImportState(
              busy: true,
              phase: 'match',
              done: i + 1,
              total: films.length,
              networkWarning: warning);
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (_active(generation)) {
        state = LetterboxdImportState(
            ready: true,
            records: results,
            networkWarning: warning,
            total: films.length,
            done: films.length);
      }
    } finally {
      client?.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> choose(int index, String identity) async {
    if (state.busy ||
        !state.ready ||
        index < 0 ||
        index >= state.records.length) {
      return;
    }
    final preview = state;
    final record = preview.records[index];
    final choice =
        record.choices.where((c) => c.identity == identity).firstOrNull;
    if (identity.isNotEmpty && choice == null) return;
    final generation = ++_generation;
    state = LetterboxdImportState(
        busy: true,
        phase: 'match',
        records: preview.records,
        ready: true,
        total: 1);
    DiscoveryClient? client;
    try {
      var work = choice;
      if (work != null && work.traits.isEmpty && work.tmdbId != null) {
        client = createClient?.call();
        _client = client;
        if (client == null) throw const DiscoveryUnavailable();
        work = await LetterboxdResolver(client).details(work.tmdbId!);
      }
      if (!_active(generation)) return;
      final records = [...preview.records];
      records[index] = LetterboxdRecord(record.film, work: work, choices: [
        if (work != null) work,
        ...record.choices.where((c) => c.identity != work?.identity)
      ]);
      state = LetterboxdImportState(
          ready: true,
          records: records,
          networkWarning: preview.networkWarning);
    } catch (_) {
      if (_active(generation)) {
        state = LetterboxdImportState(
            ready: true,
            records: preview.records,
            networkWarning: true,
            error: 'network');
      }
    } finally {
      client?.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> commit() async {
    if (state.busy || !state.ready || !isCurrent()) return;
    final preview = state;
    final generation = ++_generation;
    state = LetterboxdImportState(
        busy: true, phase: 'save', ready: true, records: preview.records);
    try {
      await store.save(
          LetterboxdSnapshot(
              updatedAt: DateTime.now().toUtc(), records: preview.records),
          isCurrent: () => _active(generation));
      if (_active(generation)) state = const LetterboxdImportState(saved: true);
    } catch (_) {
      if (_active(generation)) {
        state = LetterboxdImportState(
            ready: true, records: preview.records, error: 'storage');
      }
    }
  }

  Future<void> clear() async {
    if (state.busy || !isCurrent()) return;
    final generation = ++_generation;
    state = const LetterboxdImportState(busy: true, phase: 'save');
    try {
      await store.clear(isCurrent: () => _active(generation));
      if (_active(generation)) state = const LetterboxdImportState();
    } catch (_) {
      if (_active(generation)) {
        state = const LetterboxdImportState(error: 'storage');
      }
    }
  }

  void fileError() {
    if (mounted) state = const LetterboxdImportState(error: 'file');
  }
}

final _letterboxdLibraryProvider =
    FutureProvider.autoDispose<List<LetterboxdWork>>((ref) async {
  final played = ref.watch(playedItemsProvider.future);
  final unwatched = ref.watch(unwatchedLibraryProvider.future);
  return letterboxdLibraryWorks([...await played, ...await unwatched]);
});
final letterboxdImportProvider = StateNotifierProvider.autoDispose<
    LetterboxdImportController, LetterboxdImportState>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  final credentials =
      ref.watch(userProvider.select((u) => u?.seerrCredentials));
  return LetterboxdImportController(
      store: LetterboxdStore(
          ref.watch(appDatabaseProvider), scope ?? 'unconnected'),
      isCurrent: () =>
          scope != null && ref.read(letterboxdScopeProvider) == scope,
      loadLibrary: () async {
        final sub = ref.listen(_letterboxdLibraryProvider, (_, __) {});
        try {
          return await ref.read(_letterboxdLibraryProvider.future);
        } finally {
          sub.close();
        }
      },
      createClient: () => credentials?.isConfigured != true
          ? null
          : DiscoveryClient(
              baseUrl: Uri.parse(
                  (KinosConfig.seerrBaseUrl ?? credentials!.serverUrl).trim()),
              headers: {
                  if (credentials!.apiKey.trim().isNotEmpty)
                    'X-Api-Key': credentials.apiKey.trim()
                  else if (credentials.sessionCookie.trim().isNotEmpty)
                    'Cookie': credentials.sessionCookie.trim(),
                  ...credentials.customHeaders
                }));
});
final letterboxdPickExportProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['zip'],
              allowMultiple: false);
          if (result == null) return null;
          final selected = result.files.single;
          if (selected.size > letterboxdMaxArchiveBytes) {
            throw const FormatException('ZIP size');
          }
          if (selected.bytes != null) return selected.bytes!;
          if (selected.path == null) throw const FormatException('ZIP file');
          final file = File(selected.path!);
          if (await file.length() > letterboxdMaxArchiveBytes) {
            throw const FormatException('ZIP size');
          }
          return file.readAsBytes();
        });
