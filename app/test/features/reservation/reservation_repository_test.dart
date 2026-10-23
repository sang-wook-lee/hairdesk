import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/customer/customer.dart';
import 'package:hairdesk/features/customer/customer_repository.dart';
import 'package:hairdesk/features/reservation/reservation_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 저장소가 서버와 주고받는 "모양"(주소, 파라미터, JSON)을 확인한다.
/// 화면 테스트는 가짜 저장소를 쓰므로, 실제 저장소가 맞는 요청을 만드는지는 여기서만 검증된다.
void main() {
  test('예약 등록: 서울 시각 문자열과 id만 보내고, 메모가 없으면 키를 빼서 보낸다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'id': 7,
          'customerId': 1,
          'customerName': '김민지',
          'customerPhone': '01012345678',
          'menuId': 2,
          'menuName': '펌',
          'startAt': '2026-10-23T14:00:00+09:00',
          'endAt': '2026-10-23T16:00:00+09:00',
          'status': 'BOOKED',
          'memo': null,
        })),
        201,
      );
    });

    final created = await ReservationRepository(ApiClient(httpClient: client)).create(
      customerId: 1,
      menuId: 2,
      startAt: DateTime(2026, 10, 23, 14, 0),
    );

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/reservations');
    expect(jsonDecode(utf8.decode(sent.bodyBytes)), {
      'customerId': 1,
      'menuId': 2,
      'startAt': '2026-10-23T14:00:00+09:00',
    });
    expect(created.id, 7);
    expect(created.menuName, '펌');
  });

  test('고객 검색: keyword와 페이지 크기를 보내고 content만 꺼낸다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'content': [
            {'id': 1, 'name': '김민지', 'phone': '01012345678', 'memo': null},
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        })),
        200,
      );
    });

    final result = await CustomerRepository(ApiClient(httpClient: client)).search(' 5678 ');

    expect(requested.path, '/api/customers');
    expect(requested.queryParameters, {'keyword': '5678', 'page': '0', 'size': '20'}); // 앞뒤 공백 제거
    expect(result.single.name, '김민지');
  });

  test('고객 등록: 이름, 번호, 메모를 보내고 메모가 없으면 키를 뺀다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(
        utf8.encode('{"id":3,"name":"이하늘","phone":"01099990000","memo":null}'),
        201,
      );
    });

    final created = await CustomerRepository(ApiClient(httpClient: client))
        .create(const CustomerInput(name: '이하늘', phone: '010-9999-0000'));

    expect(jsonDecode(utf8.decode(sent.bodyBytes)), {'name': '이하늘', 'phone': '010-9999-0000'});
    expect(created.id, 3);
  });
}
