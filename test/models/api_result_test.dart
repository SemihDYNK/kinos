import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/models/api_result.dart';

void main() {
  test('conversion errors on HTTP 200 stay failures in both API result paths',
      () async {
    final response = Response<String>(http.Response('invalid', 200), null,
        error: const FormatException('Invalid response'));
    for (final result in [
      response.apiResult,
      await Future.value(response).apiResult
    ]) {
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.errorMessage, contains('Invalid response'));
    }
  });
  test('successful no-content and failed HTTP responses keep their meanings',
      () async {
    for (final response in [
      Response<dynamic>(http.Response('', 204), null),
      Response<String>(http.Response('ok', 200), 'ok'),
      Response<String>(http.Response('failed', 403), null, error: 'Forbidden'),
    ]) {
      for (final result in [
        response.apiResult,
        await Future.value(response).apiResult
      ]) {
        expect(result.isSuccess, response.statusCode < 300);
        expect(result.data, response.body,
            reason: '${response.statusCode} ${result.runtimeType}');
      }
    }
  });
}
