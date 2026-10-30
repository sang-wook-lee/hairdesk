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

  test('기간 매출 요약: 날짜 범위를 보내고 총액과 건수를 읽는다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      // 서버는 결제수단별 내역(byMethod)도 주지만 앱은 총액과 건수만 쓴다. 모르는 필드는 무시해야 한다.
      return http.Response.bytes(
        utf8.encode('{"totalAmount":88000,"count":3,"byMethod":[{"method":"CARD","totalAmount":88000,"count":3}]}'),
        200,
      );
    });

    final summary = await SaleRepository(ApiClient(httpClient: client))
        .summarize(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

    expect(requested.path, '/api/sales/summary');
    expect(requested.queryParameters, {'from': '2026-10-01', 'to': '2026-10-31'});
    expect(summary.totalAmount, 88000);
    expect(summary.count, 3);
  });

  group('SalesSummary 읽기', () {
    test('결제수단별 내역(byMethod)을 읽는다', () {
      final summary = SalesSummary.fromJson({
        'totalAmount': 1622000,
        'count': 30,
        'byMethod': [
          {'method': 'CARD', 'totalAmount': 713000, 'count': 14},
          {'method': 'CASH', 'totalAmount': 441000, 'count': 9},
          {'method': 'TRANSFER', 'totalAmount': 468000, 'count': 7},
        ],
      });

      expect(summary.byMethod.map((m) => m.method),
          [PaymentMethod.card, PaymentMethod.cash, PaymentMethod.transfer]);
      expect(summary.byMethod.first.totalAmount, 713000);
      expect(summary.byMethod.first.count, 14);
    });

    test('매출이 없는 기간(byMethod가 빈 목록)이나 byMethod가 아예 없는 응답도 읽는다', () {
      final empty = SalesSummary.fromJson({'totalAmount': 0, 'count': 0, 'byMethod': []});
      final missing = SalesSummary.fromJson({'totalAmount': 18000, 'count': 1}); // 홈 화면 테스트용 가짜와 같은 모양

      expect(empty.byMethod, isEmpty);
      expect(missing.byMethod, isEmpty);
      expect(missing.totalAmount, 18000);
    });
  });
}
