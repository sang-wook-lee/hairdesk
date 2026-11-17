import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/stats_data.dart';
import 'package:hairdesk/features/stats/stats_page.dart';

import '../../support/fakes.dart';
import '../../support/stats_samples.dart';

/// 통계 페이지 조립 테스트. 서버 대신 가짜 저장소를 쓰고, 오늘은 2026-11-17로 고정한다.
final _now = DateTime.parse('2026-11-17T10:00:00+09:00');

class _Harness {
  _Harness({FakeSaleRepository? sales, FakeStatsRepository? stats})
      : sales = sales ?? _defaultSales(),
        stats = stats ?? _defaultStats();

  final FakeSaleRepository sales;
  final FakeStatsRepository stats;

  /// 10월: 1~17일 안에 5만 원, 18일 이후에 99,999원. 11월: 8만 원(2건).
  static FakeSaleRepository _defaultSales() => FakeSaleRepository(ledger: [
        (date: DateTime(2026, 9, 5), amount: 10000),
        (date: DateTime(2026, 10, 3), amount: 30000),
        (date: DateTime(2026, 10, 17), amount: 20000),
        (date: DateTime(2026, 10, 18), amount: 99999),
        (date: DateTime(2026, 11, 3), amount: 50000),
        (date: DateTime(2026, 11, 12), amount: 30000),
      ]);

  static FakeStatsRepository _defaultStats() => FakeStatsRepository(
        daily: dailyOf(2026, 11, {3: 50000, 12: 30000}),
        menus: const [
          MenuSales(menuId: 4, menuName: '셋팅 펌', totalAmount: 50000, count: 1),
          MenuSales(menuId: 2, menuName: '여성 커트', totalAmount: 30000, count: 1),
        ],
        customers: const CustomerStats(totalCustomers: 2, newCustomers: 1, returningCustomers: 1),
        reservations: const ReservationStats(booked: 3, completed: 2, cancelled: 0, noShow: 1, noShowRate: 1 / 3),
      );

  int get loads => stats.requests.where((r) => r.startsWith('daily:')).length;

  Future<void> pump(WidgetTester tester, {Listenable? refresh}) async {
    tester.view.physicalSize = const Size(800, 3000); // 통계 화면은 길어서 키 큰 화면에서 본다
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: StatsPage(
        loader: StatsLoader(stats: stats, sales: sales),
        refresh: refresh,
        clock: () => _now,
      ),
    ));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('처음 화면', () {
    testWidgets('이번 달(11월) 통계를 불러와 구역별로 보여준다', (tester) async {
      await _Harness().pump(tester);

      expect(find.text('2026년 11월'), findsOneWidget);
      expect(find.text('80,000원'), findsOneWidget); // 총 매출
      expect(find.text('+60%'), findsOneWidget); // 지난달 같은 기간(10/1~17) 5만 원 → 8만 원
      expect(find.text('지난달 같은 기간 대비'), findsOneWidget);
      for (final title in ['일별 매출', '결제수단', '메뉴별 매출', '고객', '예약']) {
        expect(find.text(title), findsOneWidget, reason: '$title 구역');
      }
      expect(find.text('셋팅 펌'), findsOneWidget);
      expect(find.text('2명'), findsOneWidget); // 고객
    });

    testWidgets('이번 달은 다음 달 버튼이 비활성화되고 "이번 달" 버튼이 없다', (tester) async {
      await _Harness().pump(tester);

      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
      expect(find.text('이번 달'), findsNothing);
    });

    testWidgets('로딩 중에는 진행 표시를 보여주고, 달 이동 줄은 계속 보인다', (tester) async {
      final h = _Harness();
      h.stats.gate = Completer<void>(); // 서버가 아직 응답하지 않는 상태
      await tester.pumpWidget(MaterialApp(
        home: StatsPage(loader: StatsLoader(stats: h.stats, sales: h.sales), clock: () => _now),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('2026년 11월'), findsOneWidget);

      h.stats.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('달 이동', () {
    testWidgets('이전 달로 가면 그 달 통계를 불러오고 "전월 대비"로 바뀌며 "이번 달" 버튼이 생긴다', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();

      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('149,999원'), findsOneWidget); // 10월 전체
      expect(find.text('전월 대비'), findsOneWidget);
      expect(find.text('이번 달'), findsOneWidget);
      expect(h.stats.requests.where((r) => r.startsWith('daily:2026-10-01~2026-10-31')).length, 1);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
    });

    testWidgets('"이번 달" 버튼과 다음 달 버튼으로 돌아온다', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 9월'), findsOneWidget);

      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 10월'), findsOneWidget);

      await tester.tap(find.text('이번 달'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 11월'), findsOneWidget);
      expect(find.text('이번 달'), findsNothing);
    });

    testWidgets('해가 바뀌는 달 이동: 1월에서 이전 달은 작년 12월', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(const SizedBox()); // 깨끗한 시작
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: StatsPage(
          loader: StatsLoader(stats: h.stats, sales: h.sales),
          clock: () => DateTime.parse('2027-01-10T10:00:00+09:00'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2027년 1월'), findsOneWidget);

      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();

      expect(find.text('2026년 12월'), findsOneWidget);
    });

    testWidgets('달을 빠르게 넘겨도 먼저 시작한 요청이 늦게 끝나서 화면을 덮어쓰지 않는다', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      // 10월 요청을 일부러 늦춘다
      final slow = Completer<void>();
      h.stats.gate = slow;
      await tester.tap(find.byTooltip('이전 달')); // 10월 요청(응답 지연 중)
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 기다리지 않고 바로 9월로 한 번 더 넘긴다. 이번 요청은 지연 없이 응답한다.
      h.stats.gate = null;
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 9월'), findsOneWidget);
      expect(find.text('10,000원'), findsWidgets); // 9월 매출 (총 매출과 건당 평균이 같은 값이라 두 곳)

      // 이제서야 10월 응답이 도착한다
      slow.complete();
      await tester.pumpAndSettle();

      expect(find.text('2026년 9월'), findsOneWidget);
      expect(find.text('10,000원'), findsWidgets);
      expect(find.text('149,999원'), findsNothing); // 10월 데이터로 덮어쓰이지 않았다
    });
  });

  group('빈 달과 오류', () {
    testWidgets('매출이 없는 달은 각 구역이 안내 문구로 바뀌고, 평균은 "-", 비교는 "비교할 매출 없음"이다', (tester) async {
      final h = _Harness(sales: FakeSaleRepository(), stats: FakeStatsRepository());
      await h.pump(tester);

      expect(find.text('0원'), findsOneWidget);
      expect(find.text('0건'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('비교할 매출 없음'), findsOneWidget);
      expect(find.text('이 달은 매출이 없어요'), findsOneWidget);
      expect(find.text('결제 내역이 없어요'), findsOneWidget);
      expect(find.text('이 달에 팔린 메뉴가 없어요'), findsOneWidget);
      expect(find.text('이 달에 방문한 고객이 없어요'), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget); // 노쇼율
      expect(tester.takeException(), isNull);
    });

    testWidgets('서버가 실패하면 그 메시지와 "다시 시도"가 나오고, 복구되면 다시 불러온다', (tester) async {
      final h = _Harness();
      h.stats.failWith = ApiException(500, '서버 오류');
      await h.pump(tester);

      expect(find.text('서버 오류'), findsOneWidget);
      expect(find.text('2026년 11월'), findsOneWidget); // 달 이동 줄은 오류 중에도 보인다

      h.stats.failWith = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('80,000원'), findsOneWidget);
    });

    testWidgets('서버에 연결할 수 없으면 연결 안내를 보여준다', (tester) async {
      final h = _Harness();
      h.stats.failWith = Exception('connection refused');
      await h.pump(tester);

      expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
    });

    testWidgets('오류 화면에서도 달을 바꿔 다시 시도할 수 있다', (tester) async {
      final h = _Harness();
      h.stats.failWith = ApiException(500, '서버 오류');
      await h.pump(tester);

      h.stats.failWith = null;
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();

      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('149,999원'), findsOneWidget);
    });
  });

  group('새로고침', () {
    testWidgets('새로고침 아이콘은 보던 달을 다시 불러온다', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(h.loads, 1);

      await tester.tap(find.byTooltip('새로고침'));
      await tester.pumpAndSettle();

      expect(h.loads, 2);
      expect(find.text('2026년 11월'), findsOneWidget);
    });

    testWidgets('아래로 당기면 새로고침된다', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      // 새로고침은 화면 높이의 25% 이상 당겨야 발동한다. 이 테스트 화면은 높이가 3000이라 750 넘게 당긴다.
      await tester.drag(find.byType(ListView), const Offset(0, 1200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(h.loads, 2);
    });

    testWidgets('부모가 보내는 새로고침 신호를 받으면 보던 달 그대로 다시 불러온다', (tester) async {
      final signal = ValueNotifier<int>(0);
      addTearDown(signal.dispose);
      final h = _Harness();
      await h.pump(tester, refresh: signal);
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(h.loads, 2); // 11월, 10월

      signal.value++;
      await tester.pumpAndSettle();

      expect(h.loads, 3);
      expect(find.text('2026년 10월'), findsOneWidget); // 이번 달로 돌아가지 않는다
    });

    testWidgets('화면이 사라진 뒤에 신호가 와도 에러 없이 무시한다 (구독을 풀었다)', (tester) async {
      final signal = ValueNotifier<int>(0);
      addTearDown(signal.dispose);
      final h = _Harness();
      await h.pump(tester, refresh: signal);
      final loadsBefore = h.loads;

      await tester.pumpWidget(const SizedBox()); // 통계 화면을 없앤다
      signal.value++;
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(h.loads, loadsBefore);
    });
  });
}
