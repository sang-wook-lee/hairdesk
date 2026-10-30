import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/stats/stats_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 통계 저장소 테스트. 아래 JSON은 실제 서버(`/api/stats/...`)가 돌려준 응답 모양을 그대로 옮긴 것이다.
/// 서버 응답이 바뀌면 이 테스트가 먼저 깨져서 알려 준다.
void main() {
  /// 경로별로 정해진 응답을 돌려주고, 들어온 요청 주소를 기록하는 가짜 서버.
  ({StatsRepository repo, List<Uri> requests}) repoWith(Map<String, Object> responses, {int status = 200}) {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final body = responses[request.url.path];
      if (body == null) return http.Response('not found', 404);
      // Spring처럼 charset 없이 UTF-8 바이트로 응답한다 (한글이 깨지지 않는지도 함께 확인된다)
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    });
    return (repo: StatsRepository(ApiClient(httpClient: client)), requests: requests);
  }

  group('일별 매출', () {
    test('날짜는 시각 없는 서울 날짜로, 금액과 건수는 그대로 읽고, 기간을 쿼리로 보낸다', () async {
      final s = repoWith({
        '/api/stats/sales/daily': [
          {'date': '2026-10-01', 'totalAmount': 40000, 'count': 1},
          {'date': '2026-10-02', 'totalAmount': 0, 'count': 0}, // 매출 없는 날도 0으로 온다
        ],
      });

      final days = await s.repo.dailySales(DateTime(2026, 10, 1), DateTime(2026, 10, 2));

      expect(s.requests.single.queryParameters, {'from': '2026-10-01', 'to': '2026-10-02'});
      expect(days.length, 2);
      expect(days[0].date, DateTime(2026, 10, 1));
      expect(days[0].totalAmount, 40000);
      expect(days[0].count, 1);
      expect(days[1].totalAmount, 0);
    });

    test('기간이 너무 길어 서버가 거절하면(400) 서버 메시지를 담은 ApiException이 된다', () async {
      final s = repoWith({
        '/api/stats/sales/daily': {'status': 400, 'detail': '일별 통계는 최대 366일까지 조회할 수 있습니다.'},
      }, status: 400);

      expect(
        () => s.repo.dailySales(DateTime(2025, 1, 1), DateTime(2026, 12, 31)),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', contains('366일'))),
      );
    });
  });

  group('월별 매출', () {
    test('연도를 보내고 "2026-10" 형식의 달 이름으로 읽는다', () async {
      final s = repoWith({
        '/api/stats/sales/monthly': [
          {'month': '2026-09', 'totalAmount': 3127000, 'count': 47},
          {'month': '2026-10', 'totalAmount': 1622000, 'count': 30},
        ],
      });

      final months = await s.repo.monthlySales(2026);

      expect(s.requests.single.queryParameters, {'year': '2026'});
      expect(months.map((m) => m.month), ['2026-09', '2026-10']);
      expect(months[1].totalAmount, 1622000);
    });
  });

  group('메뉴별 매출', () {
    test('서버가 준 순서(총액이 큰 순)를 유지하고 한글 메뉴 이름이 깨지지 않는다', () async {
      final s = repoWith({
        '/api/stats/sales/by-menu': [
          {'menuId': 4, 'menuName': '셋팅 펌', 'totalAmount': 546000, 'count': 5},
          {'menuId': 2, 'menuName': '여성 커트', 'totalAmount': 300000, 'count': 12},
        ],
      });

      final menus = await s.repo.salesByMenu(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(menus.map((m) => m.menuName), ['셋팅 펌', '여성 커트']);
      expect(menus.first.menuId, 4);
      expect(menus.first.totalAmount, 546000);
      expect(menus.first.count, 5);
    });

    test('매출이 없는 기간은 빈 목록이다', () async {
      final s = repoWith({'/api/stats/sales/by-menu': <Object>[]});

      expect(await s.repo.salesByMenu(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), isEmpty);
    });
  });

  group('고객 통계', () {
    test('전체, 신규, 재방문 수를 읽는다', () async {
      final s = repoWith({
        '/api/stats/customers': {'totalCustomers': 12, 'newCustomers': 4, 'returningCustomers': 8},
      });

      final c = await s.repo.customerStats(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(c.totalCustomers, 12);
      expect(c.newCustomers, 4);
      expect(c.returningCustomers, 8);
    });
  });

  group('예약 통계', () {
    test('상태별 건수와 노쇼율(0~1 사이 소수)을 읽는다', () async {
      final s = repoWith({
        '/api/stats/reservations': {
          'booked': 10,
          'completed': 30,
          'cancelled': 1,
          'noShow': 3,
          'noShowRate': 0.09090909090909091,
        },
      });

      final r = await s.repo.reservationStats(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(r.booked, 10);
      expect(r.completed, 30);
      expect(r.cancelled, 1);
      expect(r.noShow, 3);
      expect(r.noShowRate, closeTo(0.0909, 0.0001));
    });

    test('결과가 난 예약이 없는 기간은 노쇼율 0.0이고, 서버가 0.0 대신 0으로 보내도 읽는다', () async {
      final asDecimal = repoWith({
        '/api/stats/reservations': {'booked': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'noShowRate': 0.0},
      });
      final asInteger = repoWith({
        '/api/stats/reservations': {'booked': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0, 'noShowRate': 0},
      });

      final a = await asDecimal.repo.reservationStats(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      final b = await asInteger.repo.reservationStats(DateTime(2026, 1, 1), DateTime(2026, 1, 31));

      expect(a.noShowRate, 0.0);
      expect(b.noShowRate, 0.0);
    });
  });
}
