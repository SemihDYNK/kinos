import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DiscoveryUnavailable implements Exception {
  final DateTime? retryAt;
  const DiscoveryUnavailable({this.retryAt});
}

/// Dedicated, cancellable client. No ambient user reads, no secret logging.
/// Concurrency is bounded by map(); every request also passes a pacing gate.
class DiscoveryClient {
  final Uri baseUrl;
  final Map<String, String> headers;
  final http.Client _http;
  final Duration interval;
  final Duration timeout;
  final int concurrency;
  final _cancelled = Completer<void>();
  Future<void> _gate = Future.value();
  DateTime _nextStart = DateTime.fromMillisecondsSinceEpoch(0);
  bool failed = false;
  bool get isClosed => _cancelled.isCompleted;

  DiscoveryClient({
    required this.baseUrl,
    required this.headers,
    http.Client? client,
    this.interval = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 15),
    this.concurrency = 2,
  })  : assert(concurrency > 0),
        _http = client ?? http.Client();

  void check() {
    if (isClosed) throw const DiscoveryUnavailable();
  }

  void close() {
    if (!isClosed) {
      _cancelled.complete();
      _http.close();
    }
  }

  Future<void> _wait(Duration duration) async {
    if (duration > Duration.zero) {
      await Future.any([Future<void>.delayed(duration), _cancelled.future]);
    }
    check();
  }

  Future<void> _pace() async {
    final previous = _gate;
    final turn = Completer<void>();
    _gate = turn.future;
    try {
      await previous;
      check();
      while (_nextStart.isAfter(DateTime.now())) {
        await _wait(_nextStart.difference(DateTime.now()));
      }
      _nextStart = DateTime.now().add(interval);
    } finally {
      turn.complete();
    }
  }

  Future<Map<String, dynamic>> get(String path,
      {String? language, Map<String, String> query = const {}}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await _pace();
      final prefix = baseUrl.path.replaceFirst(RegExp(r'/$'), '');
      final uri = baseUrl.replace(
          path: '$prefix/api/v1/$path',
          queryParameters: {
            ...query,
            if (language != null) 'language': language
          },
          fragment: '');
      final response = await Future.any([
        _http.get(uri, headers: headers).timeout(timeout),
        _cancelled.future
            .then<http.Response>((_) => throw const DiscoveryUnavailable()),
      ]);
      check();
      if (response.statusCode == 429) {
        final retryAt =
            retryAfter(response.headers['retry-after'], DateTime.now());
        if (retryAt.isAfter(_nextStart)) _nextStart = retryAt;
        if (attempt == 1 ||
            retryAt.difference(DateTime.now()) > const Duration(seconds: 30)) {
          throw DiscoveryUnavailable(retryAt: retryAt);
        }
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const DiscoveryUnavailable();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Seerr response');
      }
      return decoded;
    }
    throw const DiscoveryUnavailable();
  }

  Future<List<R>> map<T, R>(List<T> input, Future<R> Function(T) action) async {
    final results = List<R?>.filled(input.length, null);
    var cursor = 0;
    Object? failure;
    StackTrace? failureStack;
    Future<void> worker() async {
      while (cursor < input.length) {
        check();
        final index = cursor++;
        try {
          results[index] = await action(input[index]);
        } catch (error, stack) {
          if (!isClosed) {
            failed = true;
            failure = error;
            failureStack = stack;
          }
          close();
          rethrow;
        }
      }
    }

    try {
      await Future.wait(List.generate(concurrency, (_) => worker()));
    } catch (_) {
      if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
      rethrow;
    }
    return results.cast<R>();
  }
}

DateTime retryAfter(String? value, DateTime now) {
  final seconds = int.tryParse(value ?? '');
  if (seconds != null && seconds >= 0) {
    return now.add(Duration(seconds: seconds));
  }
  if (value != null) {
    try {
      final date = HttpDate.parse(value);
      if (date.isAfter(now)) return date;
    } on FormatException {/* Fall back to a conservative delay. */}
  }
  return now.add(const Duration(seconds: 5));
}
