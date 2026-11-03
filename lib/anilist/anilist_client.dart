import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'mapping.dart';

class AnilistUnavailable implements Exception {
  final DateTime? retryAt;
  final int? statusCode;
  const AnilistUnavailable({this.retryAt, this.statusCode});
}

class AnilistUnauthorized extends AnilistUnavailable {
  const AnilistUnauthorized();
}

class AnilistListEntry {
  final int progress;
  final String status;
  const AnilistListEntry(this.progress, this.status);
}

class AnilistClient {
  final http.Client _http;
  final Duration interval;
  final String? token;
  final Duration timeout;
  final _cancelled = Completer<void>();
  Future<void> _queue = Future.value();
  DateTime _next = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _retryAt;
  AnilistClient(
      {http.Client? client,
      this.token,
      this.interval = const Duration(seconds: 2),
      this.timeout = const Duration(seconds: 15)})
      : _http = client ?? http.Client();
  bool get isClosed => _cancelled.isCompleted;
  void close() {
    if (!isClosed) {
      _cancelled.complete();
      _http.close();
    }
  }

  void _check() {
    if (isClosed) throw const AnilistUnavailable();
  }

  Future<T> _interruptible<T>(Future<T> task) => Future.any([
        task,
        _cancelled.future.then<T>((_) => throw const AnilistUnavailable())
      ]);
  static const _fields =
      'id idMal type title { userPreferred romaji english native } format episodes startDate { year }';
  Future<Map<String, dynamic>> _request(
      String query, Map<String, Object?> variables) async {
    _check();
    final previous = _queue;
    final turn = Completer<void>();
    _queue = turn.future;
    try {
      await _interruptible(previous);
      _check();
      if (_retryAt case final DateTime retry
          when retry.isAfter(DateTime.now())) {
        throw AnilistUnavailable(retryAt: retry);
      }
      final delay = _next.difference(DateTime.now());
      if (delay > Duration.zero) {
        await _interruptible(Future<void>.delayed(delay));
      }
      _check();
      _next = DateTime.now().add(interval);
      final abort = Completer<void>();
      final request = http.AbortableRequest(
          'POST', Uri.parse('https://graphql.anilist.co'),
          abortTrigger: Future.any([abort.future, _cancelled.future]))
        ..headers.addAll(const {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        })
        ..body = jsonEncode({'query': query, 'variables': variables});
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      final response = await _interruptible((() async {
        final response = await _http.send(request);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw const AnilistUnavailable();
          }
          bytes.add(chunk);
        }
        return http.Response.bytes(bytes.takeBytes(), response.statusCode,
            headers: response.headers);
      })()
          .timeout(timeout, onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        throw const AnilistUnavailable();
      }).whenComplete(() {
        if (!abort.isCompleted) abort.complete();
      }));
      _check();
      if (token != null && [401, 403].contains(response.statusCode)) {
        throw const AnilistUnauthorized();
      }
      if (response.statusCode == 429) {
        final value = response.headers['retry-after'];
        final seconds = int.tryParse(value ?? '');
        DateTime? date;
        if (seconds != null && seconds > 0) {
          date = DateTime.now().add(Duration(seconds: seconds));
        } else if (value != null) {
          try {
            date = HttpDate.parse(value);
          } on FormatException {/* Use the pacing interval below. */}
        }
        _retryAt = date != null && date.isAfter(DateTime.now())
            ? date
            : DateTime.now().add(interval);
        throw AnilistUnavailable(retryAt: _retryAt);
      }
      if (response.statusCode == 404) return {};
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 2 * 1024 * 1024) {
        throw AnilistUnavailable(statusCode: response.statusCode);
      }
      final body = jsonDecode(response.body);
      if (token != null && body is Map && body['errors'] is List) {
        final errors = body['errors'] as List;
        if (errors.any(
            (error) => error is Map && [401, 403].contains(error['status']))) {
          throw const AnilistUnauthorized();
        }
      }
      if (body is! Map<String, dynamic> ||
          body['errors'] != null ||
          body['data'] is! Map<String, dynamic>) {
        throw AnilistUnavailable(statusCode: response.statusCode);
      }
      return body['data'] as Map<String, dynamic>;
    } on AnilistUnavailable {
      rethrow;
    } on Exception {
      throw const AnilistUnavailable();
    } finally {
      turn.complete();
    }
  }

  Future<({int id, String name})> viewer() async {
    if (token == null) throw const AnilistUnauthorized();
    final data = await _request('query { Viewer { id name } }', {});
    final viewer = data['Viewer'];
    if (viewer is! Map ||
        positiveId(viewer['id']) == null ||
        viewer['name'] is! String ||
        (viewer['name'] as String).trim().isEmpty) {
      throw const AnilistUnavailable();
    }
    return (id: positiveId(viewer['id'])!, name: viewer['name'] as String);
  }

  Future<AnilistListEntry?> listEntry(int mediaId, int userId) async {
    if (token == null) throw const AnilistUnauthorized();
    final data = await _request(
        r'query ($mediaId:Int!, $userId:Int!) { MediaList(mediaId:$mediaId,userId:$userId,type:ANIME) { progress status } }',
        {'mediaId': mediaId, 'userId': userId});
    final entry = data['MediaList'];
    if (entry == null) return null;
    if (entry is! Map ||
        entry['progress'] is! int ||
        (entry['progress'] as int) < 0 ||
        !['CURRENT', 'COMPLETED', 'PAUSED', 'DROPPED', 'PLANNING', 'REPEATING']
            .contains(entry['status'])) {
      throw const AnilistUnavailable();
    }
    return AnilistListEntry(
        entry['progress'] as int, entry['status'] as String);
  }

  Future<void> saveProgress(int mediaId, int progress, {String? status}) async {
    if (token == null) throw const AnilistUnauthorized();
    if (mediaId <= 0 ||
        progress < 0 ||
        (status != null && !['CURRENT', 'COMPLETED'].contains(status))) {
      throw ArgumentError('Invalid progress');
    }
    final data = await _request(
        status == null
            ? r'mutation ($mediaId:Int!, $progress:Int!) { SaveMediaListEntry(mediaId:$mediaId,progress:$progress) { mediaId progress status } }'
            : r'mutation ($mediaId:Int!, $progress:Int!, $status:MediaListStatus) { SaveMediaListEntry(mediaId:$mediaId,progress:$progress,status:$status) { mediaId progress status } }',
        {
          'mediaId': mediaId,
          'progress': progress,
          if (status != null) 'status': status
        });
    final saved = data['SaveMediaListEntry'];
    if (saved is! Map ||
        saved['mediaId'] != mediaId ||
        saved['progress'] != progress) {
      throw const AnilistUnavailable();
    }
  }

  Future<AnilistMedia?> media({int? id, int? malId}) async {
    if ((id == null) == (malId == null) || (id ?? malId ?? 0) <= 0) {
      throw ArgumentError('One positive ID required');
    }
    final data = await _request(
        r'query ($id: Int, $malId: Int) { Media(id: $id, idMal: $malId, type: ANIME) { '
        '$_fields } }',
        {'id': id, 'malId': malId});
    if (data['Media'] == null) return null;
    if (data['Media'] is! Map<String, dynamic>) {
      throw const AnilistUnavailable();
    }
    try {
      final media =
          AnilistMedia.fromJson(data['Media'] as Map<String, dynamic>);
      if ((id != null && media.id != id) ||
          (malId != null && media.malId != malId)) {
        throw const AnilistUnavailable();
      }
      return media;
    } on Exception {
      throw const AnilistUnavailable();
    }
  }

  Future<List<AnilistMedia>> search(String title) async {
    final term = title.trim();
    if (term.isEmpty) return [];
    return _page(
        r'query ($search: String!) { Page(page: 1, perPage: 20) { media(search: $search, type: ANIME) { '
        '$_fields } } }',
        {'search': term});
  }

  Future<List<AnilistMedia>> mediaByIds(Iterable<int> ids) async {
    final values = ids.where((id) => id > 0).toSet().toList();
    final result = <AnilistMedia>[];
    for (var i = 0; i < values.length; i += 50) {
      result.addAll(await _page(
          r'query ($ids: [Int]) { Page(page: 1, perPage: 50) { media(id_in: $ids, type: ANIME) { '
          '$_fields } } }',
          {'ids': values.skip(i).take(50).toList()}));
    }
    return result;
  }

  Future<List<AnilistMedia>> _page(
      String query, Map<String, Object?> variables) async {
    final data = await _request(query, variables);
    final page = data['Page'];
    if (page is! Map || page['media'] is! List) {
      throw const AnilistUnavailable();
    }
    final result = <AnilistMedia>[];
    for (final value in page['media'] as List) {
      if (value is! Map<String, dynamic>) continue;
      if (value['type'] != 'ANIME') continue;
      try {
        result.add(AnilistMedia.fromJson(value));
      } on FormatException {/* An invalid result cannot establish a link. */}
    }
    return result;
  }
}
