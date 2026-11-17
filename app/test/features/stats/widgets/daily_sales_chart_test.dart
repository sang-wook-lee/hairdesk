import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/widgets/daily_sales_chart.dart';

import '../../../support/stats_samples.dart';

void main() {
  group('차트 계산 함수', () {
    test('막대 높이 비율 = 금액 ÷ 최고 금액', () {
      expect(barFraction(148000, 148000), 1.0);
      expect(barFraction(74000, 148000), 0.5);
      expect(barFraction(0, 148000), 0.0);
    });

    test('최고 금액이 0이면(매출이 없는 달) 0으로 나누지 않고 0', () {
      expect(barFraction(0, 0), 0.0);
    });

    test('날짜 눈금은 1일, 5의 배수, 마지막 날에 붙고 마지막 날과 붙는 5의 배수는 뺀다', () {
      List<int> labels(int lastDay) =>
          [for (var d = 1; d <= lastDay; d++) if (showAxisLabel(d, lastDay)) d];

      expect(labels(31), [1, 5, 10, 15, 20, 25, 31]); // 30은 31과 붙어서 뺀다
      expect(labels(30), [1, 5, 10, 15, 20, 25, 30]);
      expect(labels(28), [1, 5, 10, 15, 20, 25, 28]);
      expect(labels(29), [1, 5, 10, 15, 20, 25, 29]); // 윤년 2월
    });

    test('터치한 가로 위치를 막대 번호로 바꾼다 (31개, 폭 310 → 막대 하나가 10)', () {
      expect(chartIndexAt(0, 310, 31), 0);
      expect(chartIndexAt(9.9, 310, 31), 0);
      expect(chartIndexAt(10, 310, 31), 1);
      expect(chartIndexAt(155, 310, 31), 15);
      expect(chartIndexAt(309.9, 310, 31), 30);
    });

    test('영역 밖으로 밀려도 양 끝 막대로 맞춘다', () {
      expect(chartIndexAt(-50, 310, 31), 0);
      expect(chartIndexAt(400, 310, 31), 30);
    });
  });

  group('DailySalesChart 위젯', () {
    // 10월: 3일 40,000원 / 10일 74,000원 / 17일 148,000원(최고)
    final october = dailyOf(2026, 10, {3: 40000, 10: 74000, 17: 148000});

    Future<void> pumpChart(WidgetTester tester, List<DailySales> days, {DateTime? today, double width = 310}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: DailySalesChart(days: days, today: today)),
          ),
        ),
      ));
    }

    /// 그래프 영역에서 [index]번째 막대(0부터)의 가운데 위치를 화면 좌표로
    Offset barCenter(WidgetTester tester, int index, int count) {
      final area = find.byKey(const ValueKey('daily-chart-area'));
      final topLeft = tester.getTopLeft(area);
      final width = tester.getSize(area).width;
      return topLeft + Offset((index + 0.5) * width / count, 30);
    }

    testWidgets('그 달의 모든 날짜가 막대로 그려진다', (tester) async {
      await pumpChart(tester, october);

      expect(find.byWidgetPredicate((w) => w.key.toString().startsWith("[<'bar-")), findsNWidgets(31));
    });

    testWidgets('막대 높이는 최고 금액 대비 비율이다 (최고 = 영역 전체 높이, 절반 금액 = 절반 높이)', (tester) async {
      await pumpChart(tester, october);

      final best = tester.getSize(find.byKey(const ValueKey('bar-2026-10-17'))).height;
      final half = tester.getSize(find.byKey(const ValueKey('bar-2026-10-10'))).height;
      final zero = tester.getSize(find.byKey(const ValueKey('bar-2026-10-01'))).height;

      expect(best, closeTo(140, 0.5));
      expect(half, closeTo(70, 0.5)); // 140 × 74,000/148,000 = 70
      expect(half / best, closeTo(0.5, 0.01));
      expect(zero, 0);
    });

    testWidgets('아주 작은 금액도 눈에 보이게 최소 높이를 가진다', (tester) async {
      final days = dailyOf(2026, 10, {1: 1000, 2: 10000000});
      await pumpChart(tester, days);

      expect(tester.getSize(find.byKey(const ValueKey('bar-2026-10-01'))).height, greaterThan(3));
    });

    testWidgets('처음에는 최고 매출일을 안내한다', (tester) async {
      await pumpChart(tester, october);

      expect(find.text('최고 매출일 · 2026년 10월 17일 (토)'), findsOneWidget);
      expect(find.text('148,000원 · 2건'), findsOneWidget); // 건수: 1 + 148000 ~/ 80000
    });

    testWidgets('막대를 누르면 그날의 날짜, 금액, 건수가 보인다', (tester) async {
      await pumpChart(tester, october);

      await tester.tapAt(barCenter(tester, 9, 31)); // 10일
      await tester.pump();

      expect(find.text('2026년 10월 10일 (토)'), findsOneWidget);
      expect(find.text('74,000원 · 1건'), findsOneWidget);
      expect(find.textContaining('최고 매출일'), findsNothing);
    });

    testWidgets('매출이 없는 날을 눌러도 그날 0원이 보인다', (tester) async {
      await pumpChart(tester, october);

      await tester.tapAt(barCenter(tester, 0, 31)); // 1일
      await tester.pump();

      expect(find.text('2026년 10월 1일 (목)'), findsOneWidget);
      expect(find.text('0원 · 0건'), findsOneWidget);
    });

    testWidgets('좌우로 밀면 손가락 위치를 따라 선택이 바뀐다', (tester) async {
      await pumpChart(tester, october);

      final gesture = await tester.startGesture(barCenter(tester, 2, 31)); // 3일에서 시작
      // 탭과 밀기 인식기가 경쟁할 때 Flutter는 "눌렀다"를 약 0.1초 뒤에 확정한다. 그만큼 시간을 흘려 보낸다.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('40,000원 · 1건'), findsOneWidget);

      // 실제 손가락처럼 조금씩 나눠 17일까지 민다. (한 번에 점프하면 Flutter가 드래그가 아닌 다른 동작으로 볼 수 있다)
      final start = barCenter(tester, 2, 31);
      final end = barCenter(tester, 16, 31);
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(start + (end - start) * (step / 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('2026년 10월 17일 (토)'), findsOneWidget);
      expect(find.text('148,000원 · 2건'), findsOneWidget);

      await gesture.up();
    });

    testWidgets('오늘 이후 날짜는 막대가 없고 눌러도 선택되지 않는다', (tester) async {
      final today = DateTime(2026, 10, 17);
      await pumpChart(tester, october, today: today);

      // 17일까지 17개만 그려진다
      expect(find.byWidgetPredicate((w) => w.key.toString().startsWith("[<'bar-")), findsNWidgets(17));
      expect(find.byKey(const ValueKey('bar-2026-10-18')), findsNothing);

      await tester.tapAt(barCenter(tester, 9, 31)); // 10일 선택
      await tester.pump();
      await tester.tapAt(barCenter(tester, 24, 31)); // 25일(미래)은 무시
      await tester.pump();

      expect(find.text('2026년 10월 10일 (토)'), findsOneWidget); // 그대로 10일
    });

    testWidgets('매출이 하나도 없는 달은 그래프 대신 안내 문구를 보여준다', (tester) async {
      await pumpChart(tester, dailyOf(2026, 10, {}));

      expect(find.text('이 달은 매출이 없어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-chart-area')), findsNothing);
    });

    testWidgets('날짜 목록이 아예 비어 있어도 터지지 않고 안내를 보여준다', (tester) async {
      await pumpChart(tester, const []);

      expect(find.text('이 달은 매출이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('다른 달의 데이터로 바뀌면 이전 달의 선택이 초기화된다', (tester) async {
      await pumpChart(tester, october);
      await tester.tapAt(barCenter(tester, 9, 31));
      await tester.pump();
      expect(find.text('2026년 10월 10일 (토)'), findsOneWidget);

      await pumpChart(tester, dailyOf(2026, 9, {5: 90000})); // 9월(30일)로 교체
      await tester.pump();

      expect(find.textContaining('2026년 10월 10일'), findsNothing);
      expect(find.text('최고 매출일 · 2026년 9월 5일 (토)'), findsOneWidget);
    });

    testWidgets('좁은 화면(폭 200)에서도 넘치지 않고, 날짜 눈금이 보인다', (tester) async {
      await pumpChart(tester, october, width: 200);

      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('30'), findsNothing); // 마지막 날과 붙는 눈금은 뺀다
    });
  });
}
