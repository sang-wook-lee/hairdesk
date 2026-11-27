import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/core/page_result.dart';
import 'package:hairdesk/features/customer/customer_repository.dart';
import 'package:hairdesk/features/customer/customer_summary.dart';
import 'package:hairdesk/features/customer/customer_visit.dart';
import 'package:hairdesk/features/reservation/reservation.dart';
import 'package:hairdesk/features/sales/sale.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 고객 상세 화면용 데이터 층: 응답을 모델로 읽는 규칙과, 저장소가 서버 규격(주소, 쿼리)대로 부르는지 확인한다.
void main() {
  const summaryJson = {
    'visitCount': 3,
    'firstVisitAt': '2026-09-01T10:00:00+09:00',
    'lastVisitAt': '2026-10-20T15:30:00+09:00',
    'totalAmount': 150000,
    'averageAmount': 50000,
    'reservationCount': 5,
    'cancelledCount': 1,
    'noShowCount': 1,
    'lastMenuName': '펌',
    'lastStaffId': 2,
    'lastStaffName': '이지수',
    'lastStaffPosition': '실장',
  };

  const emptySummaryJson = {
    'visitCount': 0,
    'firstVisitAt': null,
    'lastVisitAt': null,
    'totalAmount': 0,
    'averageAmount': null,
    'reservationCount': 0,
    'cancelledCount': 0,
    'noShowCount': 0,
    'lastMenuName': null,
    'lastStaffId': null,
    'lastStaffName': null,
    'lastStaffPosition': null,
  };

  const visitJson = {
    'id': 7,
    'reservationId': null,
    'customerId': 1,
    'customerName': '김민지',
    'menuId': 2,
    'menuName': '펌',
    'staffId': 2,
    'staffName': '이지수',
    'staffPosition': '실장',
    'price': 80000,
    'amount': 70000,
    'discount': 10000,
    'paymentMethod': 'TRANSFER',
    'paidAt': '2026-10-20T15:30:00+09:00',
    'memo': null,
  };

  const reservationJson = {
    'id': 3,
    'customerId': 1,
    'customerName': '김민지',
    'customerPhone': '01012345678',
    'menuId': 1,
    'menuName': '커트',
    'staffId': 1,
    'staffName': '원장',
    'staffPosition': '원장',
    'startAt': '2026-12-01T14:00:00+09:00',
    'endAt': '2026-12-01T15:00:00+09:00',
    'status': 'BOOKED',
    'memo': null,
  };

  group('CustomerSummary', () {
    test('값이 다 있는 응답을 읽는다', () {
      final s = CustomerSummary.fromJson(summaryJson);

      expect(s.visitCount, 3);
      expect(s.totalAmount, 150000);
      expect(s.averageAmount, 50000);
      expect(s.reservationCount, 5);
      expect(s.cancelledCount, 1);
      expect(s.noShowCount, 1);
      expect(s.lastMenuName, '펌');
      expect(s.lastStaffId, 2);
      expect(s.lastStaffName, '이지수');
      expect(s.lastStaffPosition, '실장');
      expect(s.hasVisits, isTrue);
      // +09:00 표기를 절대 시각으로 읽는다: 2026-09-01 10:00(서울) = 01:00(UTC)
      expect(s.firstVisitAt, DateTime.utc(2026, 9, 1, 1));
      expect(s.lastVisitAt, DateTime.utc(2026, 10, 20, 6, 30));
    });

    test('방문이 없는 고객의 응답(null이 섞인 것)도 오류 없이 읽는다', () {
      final s = CustomerSummary.fromJson(emptySummaryJson);

      expect(s.hasVisits, isFalse);
      expect(s.totalAmount, 0);
      expect(s.firstVisitAt, isNull);
      expect(s.lastVisitAt, isNull);
      expect(s.averageAmount, isNull);
      expect(s.lastMenuName, isNull);
      expect(s.lastStaffId, isNull);
      expect(s.lastStaffName, isNull);
      expect(s.lastStaffPosition, isNull);
    });
  });

  group('CustomerVisit', () {
    test('방문 한 줄의 결제 시각·시술·담당·금액·결제수단을 읽고, 할인액과 담당 표시를 계산한다', () {
      final v = CustomerVisit.fromJson(visitJson);

      expect(v.id, 7);
      expect(v.menuName, '펌');
      expect(v.staffId, 2);
      expect(v.staffPosition, '실장');
      expect(v.paymentMethod, PaymentMethod.transfer);
      expect(v.paidAt, DateTime.utc(2026, 10, 20, 6, 30));
      expect(v.memo, isNull);
      expect(v.discount, 10000); // 정가 80,000 - 받은 금액 70,000
      expect(v.staffDisplayName, '이지수 (#2)');
    });
  });

  group('PageResult', () {
    test('페이지 번호·전체 개수·항목을 읽고, 뒤에 페이지가 남았는지 알려준다', () {
      Map<String, dynamic> page(int number) => {
            'content': [visitJson],
            'page': number,
            'size': 1,
            'totalElements': 3,
            'totalPages': 3,
          };

      final first = PageResult.fromJson(page(0), CustomerVisit.fromJson);
      final last = PageResult.fromJson(page(2), CustomerVisit.fromJson);

      expect(first.items, hasLength(1));
      expect(first.page, 0);
      expect(first.totalElements, 3);
      expect(first.totalPages, 3);
      expect(first.hasMore, isTrue);
      expect(last.hasMore, isFalse); // 마지막 페이지 뒤에는 더 없다
    });
  });

  group('CustomerRepository', () {
    late http.Request sent;

    CustomerRepository repositoryReturning(Object body, {int status = 200}) {
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      });
      return CustomerRepository(ApiClient(httpClient: client));
    }

    test('findById: GET /api/customers/{id}', () async {
      final repo = repositoryReturning(
        {'id': 4, 'name': '김민지', 'phone': '01012345678', 'memo': '염색 주의'},
      );

      final customer = await repo.findById(4);

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/customers/4');
      expect(customer.name, '김민지');
      expect(customer.memo, '염색 주의');
    });

    test('fetchSummary: GET /api/customers/{id}/summary', () async {
      final repo = repositoryReturning(summaryJson);

      final summary = await repo.fetchSummary(4);

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/customers/4/summary');
      expect(summary.visitCount, 3);
    });

    test('fetchVisits: 페이지 번호와 크기를 쿼리로 보내고, 기본은 0쪽 20건이다', () async {
      final repo = repositoryReturning({
        'content': [visitJson],
        'page': 2,
        'size': 5,
        'totalElements': 11,
        'totalPages': 3,
      });

      final page = await repo.fetchVisits(4, page: 2, size: 5);

      expect(sent.url.path, '/api/customers/4/visits');
      expect(sent.url.queryParameters, {'page': '2', 'size': '5'});
      expect(page.items.single.menuName, '펌');
      expect(page.hasMore, isFalse);

      await repo.fetchVisits(4);
      expect(sent.url.queryParameters, {'page': '0', 'size': '20'});
    });

    test('fetchUpcoming: 목록 응답을 예약 목록으로 읽는다', () async {
      final repo = repositoryReturning([reservationJson]);

      final reservations = await repo.fetchUpcoming(4);

      expect(sent.url.path, '/api/customers/4/upcoming-reservations');
      expect(reservations.single.status, ReservationStatus.booked);
      expect(reservations.single.menuName, '커트');
    });

    test('fetchUpcoming: 예약이 없으면 빈 목록이다', () async {
      final repo = repositoryReturning(<Object>[]);

      expect(await repo.fetchUpcoming(4), isEmpty);
    });

    test('서버가 404를 주면 안내 메시지가 담긴 ApiException이 그대로 전달된다', () async {
      final repo = repositoryReturning(
        {'status': 404, 'detail': '고객을 찾을 수 없습니다. id=9'},
        status: 404,
      );

      await expectLater(
        repo.fetchSummary(9),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', '고객을 찾을 수 없습니다. id=9')),
      );
    });
  });
}
