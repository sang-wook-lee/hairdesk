import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/stats_calculations.dart';
import 'package:hairdesk/features/stats/stats_data.dart';
import 'package:hairdesk/features/stats/stats_month.dart';

import '../../support/fakes.dart';

/// StatsLoader는 "어떤 기간으로 무엇을 부를지"와 "받은 값에서 파생 값을 만드는 것"을 맡는다.
/// 서버 대신 가짜 저장소를 쓰고, 오늘 날짜는 직접 넣어서 고정한다.
void main() {
  final today = DateTime(2026, 11, 17);

  StatsLoader loaderWith(FakeStatsRepository stats, FakeSaleRepository sales) =>
      StatsLoader(stats: stats, sales: sales);

  // 10월: 1~17일 안에 5만 원(3만+2만), 18일 이후에 99,999원. 11월: 8만 원.
  FakeSaleRepository salesLedger() => FakeSaleRepository(ledger: [
        (date: DateTime(2026, 9, 5), amount: 10000),
        (date: DateTime(2026, 10, 3), amount: 30000),
        (date: DateTime(2026, 10, 17), amount: 20000),
        (date: DateTime(2026, 10, 18), amount: 99999), // 비교 기간(10/1~10/17) 밖
        (date: DateTime(2026, 11, 3), amount: 50000),
        (date: DateTime(2026, 11, 12), amount: 30000),
      ]);

  group('이번 달 (11월, 오늘 11/17)', () {
    test('이 달 전체로 5개를 부르고, 비교 요약은 지난달 같은 기간(10/1~10/17)으로 부른다', () async {
      final stats = FakeStatsRepository();
      final sales = salesLedger();

      await loaderWith(stats, sales).load(const StatsMonth(2026, 11), today: today);

      expect(sales.summaryRequests, ['2026-11-01~2026-11-30', '2026-10-01~2026-10-17']);
      expect(stats.requests, [
        'daily:2026-11-01~2026-11-30',
        'menus:2026-11-01~2026-11-30',
        'customers:2026-11-01~2026-11-30',
        'reservations:2026-11-01~2026-11-30',
      ]);
    });

    test('총액, 비교 기간 총액, 전월 대비, 건당 평균이 계산되어 들어 있다', () async {
      final data = await loaderWith(FakeStatsRepository(), salesLedger())
          .load(const StatsMonth(2026, 11), today: today);

      expect(data.summary.totalAmount, 80000);
      expect(data.summary.count, 2);
      expect(data.previousSummary.totalAmount, 50000); // 10/18의 99,999원은 빠진다
      expect(data.change, const Changed(60)); // 5만 → 8만
      expect(data.averageAmount, 40000);
      expect(data.hasSales, isTrue);
      expect(data.comparisonLabel, '지난달 같은 기간 대비');
      expect(data.comparisonRange, DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 17)));
      expect(data.month, const StatsMonth(2026, 11));
    });

    test('서버에서 받은 일별, 메뉴별, 고객, 예약 통계를 그대로 담는다', () async {
      final stats = FakeStatsRepository(
        daily: [DailySales(date: DateTime(2026, 11, 3), totalAmount: 50000, count: 1)],
        menus: [const MenuSales(menuId: 4, menuName: '셋팅 펌', totalAmount: 50000, count: 1)],
        customers: const CustomerStats(totalCustomers: 2, newCustomers: 1, returningCustomers: 1),
        reservations: const ReservationStats(booked: 3, completed: 2, cancelled: 0, noShow: 1, noShowRate: 1 / 3),
      );

      final data = await loaderWith(stats, salesLedger()).load(const StatsMonth(2026, 11), today: today);

      expect(data.daily.single.totalAmount, 50000);
      expect(data.menus.single.menuName, '셋팅 펌');
      expect(data.customers.newCustomers, 1);
      expect(data.reservations.noShow, 1);
    });
  });

  group('이미 끝난 달 (10월을 11/17에 본다)', () {
    test('직전 달 전체(9/1~9/30)와 비교하고 "전월 대비"라고 부른다', () async {
      final sales = salesLedger();

      final data = await loaderWith(FakeStatsRepository(), sales).load(const StatsMonth(2026, 10), today: today);

      expect(sales.summaryRequests, ['2026-10-01~2026-10-31', '2026-09-01~2026-09-30']);
      expect(data.summary.totalAmount, 149999); // 10월 전체: 3만 + 2만 + 99,999
      expect(data.previousSummary.totalAmount, 10000);
      expect(data.change, const Changed(1400)); // 1만 → 149,999: +1399.99% → 1400
      expect(data.comparisonLabel, '전월 대비');
    });
  });

  group('비교할 수 없거나 값이 없는 경우', () {
    test('비교 기간에 매출이 없으면 전월 대비는 "비교 불가"다 (11월에 처음 장사한 경우 등)', () async {
      final sales = FakeSaleRepository(ledger: [(date: DateTime(2026, 11, 3), amount: 50000)]);

      final data = await loaderWith(FakeStatsRepository(), sales).load(const StatsMonth(2026, 11), today: today);

      expect(data.previousSummary.totalAmount, 0);
      expect(data.change, const NoComparison());
      expect(data.averageAmount, 50000);
    });

    test('매출이 하나도 없는 달은 건당 평균이 없고 hasSales가 false다', () async {
      final data = await loaderWith(FakeStatsRepository(), FakeSaleRepository())
          .load(const StatsMonth(2026, 11), today: today);

      expect(data.hasSales, isFalse);
      expect(data.averageAmount, isNull);
      expect(data.change, const NoComparison());
      expect(data.methodShares, isEmpty);
    });
  });

  group('실패', () {
    test('통계 호출이 실패하면 그 에러가 감싸이지 않고 그대로 나온다 (화면이 서버 메시지를 보여줄 수 있게)', () async {
      final stats = FakeStatsRepository()..failWith = ApiException(500, '서버 오류');

      expect(
        () => loaderWith(stats, salesLedger()).load(const StatsMonth(2026, 11), today: today),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', '서버 오류')),
      );
    });

    test('매출 요약 호출이 실패해도 마찬가지다', () async {
      final sales = salesLedger()..failOnSummary = ApiException(503, '점검 중');

      expect(
        () => loaderWith(FakeStatsRepository(), sales).load(const StatsMonth(2026, 11), today: today),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
    });
  });
}
