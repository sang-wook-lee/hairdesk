import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/reservation/reservation_repository.dart';
import 'package:hairdesk/features/sales/sale.dart';
import 'package:hairdesk/features/sales/sale_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 매출 저장소와 예약 상태 변경 호출이 서버 규격(주소, 메서드, JSON)에 맞는지 확인한다.
void main() {
  const reservationJson = {
    'id': 1,
    'customerId': 1,
    'customerName': '김민지',
    'customerPhone': '01012345678',
    'menuId': 1,
    'menuName': '커트',
    'startAt': '2026-10-01T11:00:00+09:00',
    'endAt': '2026-10-01T12:00:00+09:00',
    'status': 'BOOKED',
    'memo': null,
  };

  test('결제 등록: 예약 id, 금액, 결제 수단을 서버 값으로 보낸다 (메모가 없으면 키를 뺀다)', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(
        utf8.encode('{"id":5,"price":20000,"amount":18000,"paymentMethod":"CASH"}'),
        201,
      );
    });

    final sale = await SaleRepository(ApiClient(httpClient: client)).create(
      reservationId: 1,
      amount: 18000,
      method: PaymentMethod.cash,
    );

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/sales');
    expect(jsonDecode(utf8.decode(sent.bodyBytes)),
        {'reservationId': 1, 'amount': 18000, 'paymentMethod': 'CASH'});
    expect(sale.discount, 2000); // 정가 20,000 - 받은 금액 18,000
    expect(sale.paymentMethod, PaymentMethod.cash);
  });

  test('예약 시간 변경: PATCH로 서울 시각을 보낸다', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(utf8.encode(jsonEncode(reservationJson)), 200);
    });

    await ReservationRepository(ApiClient(httpClient: client)).reschedule(1, DateTime(2026, 10, 1, 11, 0));

    expect(sent.method, 'PATCH');
    expect(sent.url.path, '/api/reservations/1/time');
    expect(jsonDecode(utf8.decode(sent.bodyBytes)), {'startAt': '2026-10-01T11:00:00+09:00'});
  });

  test('예약 취소와 노쇼: 각각의 주소로 본문 없이 POST한다', () async {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      return http.Response.bytes(utf8.encode(jsonEncode(reservationJson)), 200);
    });
    final repo = ReservationRepository(ApiClient(httpClient: client));

    await repo.cancel(3);
    await repo.markNoShow(4);

    expect([for (final r in sent) '${r.method} ${r.url.path}'],
        ['POST /api/reservations/3/cancel', 'POST /api/reservations/4/no-show']);
    expect(sent.first.bodyBytes, isEmpty);
  });
}
