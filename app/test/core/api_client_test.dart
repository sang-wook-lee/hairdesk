import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('charset 없는 응답의 한글도 깨지지 않고 읽는다', () async {
    // Spring은 Content-Type에 charset을 붙이지 않는다. http 패키지의 body는 이때 latin1로 읽어 한글이 깨진다.
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode('[{"name":"커트"}]'),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final json = await ApiClient(httpClient: client).getJson('/api/menus');

    expect((json as List).first['name'], '커트');
  });

  test('에러 응답은 서버의 detail 메시지를 담은 ApiException으로 바뀐다', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode('{"status":409,"detail":"해당 시간에 이미 예약이 있습니다."}'),
        409,
        headers: {'content-type': 'application/problem+json'},
      );
    });

    expect(
      () => ApiClient(httpClient: client).getJson('/api/reservations'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', '해당 시간에 이미 예약이 있습니다.'),
      ),
    );
  });

  test('POST 본문은 UTF-8 JSON으로 보내고 한글이 보존된다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(utf8.encode('{"id":1}'), 201);
    });

    await ApiClient(httpClient: client).postJson('/api/menus', body: {'name': '커트'});

    expect(sent.method, 'POST');
    expect(sent.headers['content-type'], contains('application/json'));
    expect(utf8.decode(sent.bodyBytes), '{"name":"커트"}');
  });

  test('본문이 비어 있는 성공 응답(204)은 null을 돌려준다', () async {
    final client = MockClient((request) async => http.Response('', 204));

    final result = await ApiClient(httpClient: client).postJson('/api/menus/1/deactivate');

    expect(result, isNull);
  });

  test('서버 주소를 따로 정하지 않으면 내 컴퓨터의 서버(localhost:8080)를 쓴다', () {
    // 폰용으로 빌드할 때만 --dart-define=API_BASE_URL=... 로 바뀐다. 일반 개발·테스트는 기본값이어야 한다.
    expect(apiBaseUrl, 'http://localhost:8080');
  });

  test('쿼리 파라미터가 주소 뒤에 붙는다', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response('[]', 200);
    });

    await ApiClient(httpClient: client).getJson(
      '/api/reservations',
      query: {'from': '2026-10-01', 'to': '2026-10-07'},
    );

    expect(requested.toString(),
        'http://localhost:8080/api/reservations?from=2026-10-01&to=2026-10-07');
  });
}
