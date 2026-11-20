import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/staff/staff.dart';
import 'package:hairdesk/features/staff/staff_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 직원 저장소가 서버와 주고받는 "모양"(주소, 메서드, JSON)을 확인한다.
void main() {
  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status);

  const wonjang = {'id': 1, 'name': '원장', 'position': '원장', 'active': true};
  const jisu = {'id': 2, 'name': '이지수', 'position': '실장', 'active': true};

  test('목록: 기본은 근무 중만, includeInactive=false를 보내고 순서를 그대로 유지한다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return json([wonjang, jisu]);
    });

    final list = await StaffRepository(ApiClient(httpClient: client)).fetchAll();

    expect(requested.path, '/api/staff');
    expect(requested.queryParameters, {'includeInactive': 'false'});
    expect(list.map((s) => s.name), ['원장', '이지수']);
    expect(list.first.position, '원장');
  });

  test('목록: includeInactive를 켜면 그 값을 서버로 보낸다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return json([wonjang]);
    });

    await StaffRepository(ApiClient(httpClient: client)).fetchAll(includeInactive: true);

    expect(requested.queryParameters, {'includeInactive': 'true'});
  });

  test('등록: POST로 이름과 직책만 보내고 만들어진 직원을 돌려받는다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return json(jisu, 201);
    });

    final created = await StaffRepository(ApiClient(httpClient: client))
        .create(const StaffInput(name: '이지수', position: '실장'));

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/staff');
    expect(jsonDecode(utf8.decode(sent.bodyBytes)), {'name': '이지수', 'position': '실장'});
    expect(created.id, 2);
  });

  test('수정: PUT /api/staff/{번호}로 이름과 직책을 보낸다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return json({...jisu, 'position': '부원장'});
    });

    final updated = await StaffRepository(ApiClient(httpClient: client))
        .update(2, const StaffInput(name: '이지수', position: '부원장'));

    expect(sent.method, 'PUT');
    expect(sent.url.path, '/api/staff/2');
    expect(updated.position, '부원장');
  });

  test('근무 종료·재개: 본문 없이 각각의 주소로 POST한다', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      expect(request.bodyBytes, isEmpty);
      return http.Response('', 204);
    });
    final repository = StaffRepository(ApiClient(httpClient: client));

    await repository.setActive(2, active: false);
    await repository.setActive(2, active: true);

    expect(requests, ['POST /api/staff/2/deactivate', 'POST /api/staff/2/activate']);
  });

  test('서버가 거절하면(예: 없는 직원 번호) 서버의 메시지를 담은 ApiException이 올라온다', () async {
    final client = MockClient((request) async => json(
          {'status': 404, 'detail': '직원을 찾을 수 없습니다. 직원 번호=9'},
          404,
        ));

    expect(
      () => StaffRepository(ApiClient(httpClient: client)).setActive(9, active: false),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 404)
          .having((e) => e.message, 'message', '직원을 찾을 수 없습니다. 직원 번호=9')),
    );
  });
}
