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
