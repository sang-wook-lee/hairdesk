// 통계 위젯 테스트용 샘플 데이터. 서버 없이 StatsData와 일별 목록을 쉽게 만든다.

import 'package:hairdesk/features/sales/sale.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/stats_data.dart';
import 'package:hairdesk/features/stats/stats_month.dart';

/// 요약 카드 테스트에 필요한 값만 바꿔 StatsData를 만든다. 나머지는 의미 없는 기본값이다.
StatsData sampleStatsData({
  int total = 1622000,
  int count = 30,
  int previousTotal = 1448000,
  String comparisonLabel = '지난달 같은 기간 대비',
  List<MethodTotal> byMethod = const [],
}) {
  return StatsData(
    month: const StatsMonth(2026, 10),
    comparisonRange: DateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
    comparisonLabel: comparisonLabel,
    summary: SalesSummary(totalAmount: total, count: count, byMethod: byMethod),
    previousSummary: SalesSummary(totalAmount: previousTotal, count: 0),
    daily: const [],
    menus: const [],
    customers: const CustomerStats(totalCustomers: 0, newCustomers: 0, returningCustomers: 0),
    reservations: const ReservationStats(booked: 0, completed: 0, cancelled: 0, noShow: 0, noShowRate: 0),
  );
}

/// [year]년 [month]월의 모든 날짜를 만든다. [amounts]에 넣은 날(1일부터의 번호)만 매출이 있고 나머지는 0원이다.
/// 예: dailyOf(2026, 10, {3: 40000, 17: 148000}) → 10월 31일 중 3일과 17일만 매출 있음
List<DailySales> dailyOf(int year, int month, Map<int, int> amounts) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return [
    for (var day = 1; day <= lastDay; day++)
      DailySales(
        date: DateTime(year, month, day),
        totalAmount: amounts[day] ?? 0,
        count: (amounts[day] ?? 0) == 0 ? 0 : 1 + (amounts[day]! ~/ 80000), // 금액에 따라 건수가 달라지게
      ),
  ];
}
