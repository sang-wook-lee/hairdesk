import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/home/home_shell.dart';
import 'package:hairdesk/features/stats/stats_data.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReservationRepository reservations;
  late FakeStatsRepository stats;

  /// 통계 서버 호출 중 "일별 매출" 호출만 센다. 통계 화면이 한 번 불러올 때마다 정확히 하나씩 늘어난다.
  int statsLoads() => stats.requests.where((r) => r.startsWith('daily:')).length;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    reservations = FakeReservationRepository([]);
    stats = FakeStatsRepository();
    final sales = FakeSaleRepository();
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        reservationRepository: reservations,
        customerRepository: FakeCustomerRepository([]),
        menuRepository: FakeMenuRepository([]),
        staffRepository: FakeStaffRepository([staffOf(1, '원장', '원장')]),
        saleRepository: sales,
        statsLoader: StatsLoader(stats: stats, sales: sales),
        clock: () => DateTime.parse('2026-10-01T11:00:00+09:00'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('첫 화면은 홈이고, 아래 탭으로 일정과 메뉴를 오간다', (tester) async {
    await pump(tester);

    expect(find.text('오늘 매출'), findsOneWidget); // 홈

    await tester.tap(find.text('일정').last); // 하단 탭의 "일정"
    await tester.pumpAndSettle();
    expect(find.text('이 날은 예약이 없어요.'), findsOneWidget);

    await tester.tap(find.text('메뉴').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('등록된 메뉴가 없어요'), findsOneWidget);
  });

  testWidgets('홈의 "시술 메뉴"와 "전체 보기"가 해당 탭으로 보내 준다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('시술 메뉴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('등록된 메뉴가 없어요'), findsOneWidget);

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('이 날은 예약이 없어요.'), findsOneWidget);
  });

  testWidgets('다른 탭에 갔다가 홈으로 돌아오면 홈 데이터를 다시 불러온다', (tester) async {
    await pump(tester);
    const homeDay = '2026-10-01~2026-10-01';
    expect(reservations.requestedDates.where((d) => d == homeDay).length, 1);

    await tester.tap(find.text('일정').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();

    expect(reservations.requestedDates.where((d) => d == homeDay).length, 2);
  });

  group('통계 탭', () {
    testWidgets('처음 누르기 전에는 통계 서버를 부르지 않는다 (앱을 켤 때마다 호출 6개를 보내지 않는다)', (tester) async {
      await pump(tester);

      expect(stats.requests, isEmpty);
      expect(statsLoads(), 0);
    });

    testWidgets('처음 누르면 이번 달 통계를 한 번 불러와 보여준다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('통계').last);
      await tester.pumpAndSettle();

      expect(find.text('2026년 10월'), findsOneWidget); // 시계가 10월 1일
      expect(statsLoads(), 1);
    });

    testWidgets('홈의 "매출·통계" 버튼이 통계 탭으로 보내 준다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('매출·통계'));
      await tester.pumpAndSettle();

      expect(find.text('2026년 10월'), findsOneWidget);
      expect(statsLoads(), 1);
    });

    testWidgets('다른 탭에 갔다 돌아오면 다시 불러오고, 보던 달은 그대로 유지한다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('통계').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('이전 달')); // 9월로
      await tester.pumpAndSettle();
      expect(find.text('2026년 9월'), findsOneWidget);
      expect(statsLoads(), 2); // 10월 + 9월

      await tester.tap(find.text('일정').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('통계').last);
      await tester.pumpAndSettle();

      expect(find.text('2026년 9월'), findsOneWidget); // 이번 달로 돌아가지 않는다
      expect(statsLoads(), 3); // 같은 달을 새로 불러왔다
      expect(stats.requests.last, startsWith('reservations:2026-09-01'));
    });

    testWidgets('통계 탭 안에서 같은 탭을 다시 눌러도 불필요하게 다시 부르지 않는다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('통계').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('통계').last);
      await tester.pumpAndSettle();

      expect(statsLoads(), 1);
    });
  });
}
