import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/stats/stats_month.dart';
import 'package:hairdesk/features/stats/widgets/month_switcher.dart';
import 'package:hairdesk/features/stats/widgets/summary_card.dart';

import '../../../support/stats_samples.dart';

/// 위젯을 가운데 정렬된 고정 폭 안에 올려서 본다. (폭을 바꿔 보며 좁은 화면에서도 깨지지 않는지 확인하려고)
Future<void> pumpIn(WidgetTester tester, Widget child, {double width = 400}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
  ));
}

void main() {
  group('MonthSwitcher', () {
    Widget switcher({
      bool canGoNext = true,
      bool isCurrent = false,
      VoidCallback? onPrevious,
      VoidCallback? onNext,
      VoidCallback? onToday,
    }) {
      return MonthSwitcher(
        month: const StatsMonth(2026, 10),
        canGoNext: canGoNext,
        isCurrent: isCurrent,
        onPrevious: onPrevious ?? () {},
        onNext: onNext ?? () {},
        onToday: onToday ?? () {},
      );
    }

    testWidgets('보는 달을 "2026년 10월"로 보여준다', (tester) async {
      await pumpIn(tester, switcher());

      expect(find.text('2026년 10월'), findsOneWidget);
    });

    testWidgets('이전/다음 버튼을 누르면 각각 콜백이 불린다', (tester) async {
      var previous = 0;
      var next = 0;
      await pumpIn(tester, switcher(onPrevious: () => previous++, onNext: () => next++));

      await tester.tap(find.byTooltip('이전 달'));
      await tester.tap(find.byTooltip('다음 달'));

      expect(previous, 1);
      expect(next, 1);
    });

    testWidgets('미래의 달로는 못 가므로 다음 버튼이 비활성화되어 눌러도 콜백이 불리지 않는다', (tester) async {
      var next = 0;
      await pumpIn(tester, switcher(canGoNext: false, onNext: () => next++));

      await tester.tap(find.byTooltip('다음 달'));

      expect(next, 0);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    });

    testWidgets('이번 달을 보는 중이면 "이번 달" 버튼이 없고, 지난 달을 보면 나타나서 누르면 돌아간다', (tester) async {
      await pumpIn(tester, switcher(isCurrent: true));
      expect(find.text('이번 달'), findsNothing);

      var today = 0;
      await pumpIn(tester, switcher(isCurrent: false, onToday: () => today++));
      await tester.tap(find.text('이번 달'));

      expect(today, 1);
    });

    testWidgets('폰 폭(360)에서도 "이번 달" 버튼 글자가 한 줄에 들어간다 (두 줄로 꺾이지 않는다)', (tester) async {
      await pumpIn(tester, switcher(isCurrent: false), width: 360);

      final textHeight = tester.getSize(find.text('이번 달')).height;

      expect(textHeight, lessThan(26)); // 한 줄 높이. 두 줄로 꺾이면 40 안팎이 된다
    });

    testWidgets('좁은 화면(폭 300)에서도 넘치지 않는다', (tester) async {
      await pumpIn(tester, switcher(), width: 300);

      expect(tester.takeException(), isNull);
    });
  });

  group('StatsSummaryCard', () {
    testWidgets('총 매출, 결제 건수, 건당 평균을 보여준다', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 1622000, count: 30)));

      expect(find.text('1,622,000원'), findsOneWidget);
      expect(find.text('30건'), findsOneWidget);
      expect(find.text('54,067원'), findsOneWidget); // 1,622,000 ÷ 30
    });

    testWidgets('증가면 ▲ 초록 +%와 비교 기준 이름을 보여준다', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 112000, previousTotal: 100000)));

      expect(find.text('+12%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.text('지난달 같은 기간 대비'), findsOneWidget);
    });

    testWidgets('감소면 ▼ -%를 보여준다 (끝난 달은 "전월 대비")', (tester) async {
      await pumpIn(
        tester,
        StatsSummaryCard(data: sampleStatsData(total: 52000, previousTotal: 100000, comparisonLabel: '전월 대비')),
      );

      expect(find.text('-48%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text('전월 대비'), findsOneWidget);
    });

    testWidgets('같으면 "변동 없음"이고 화살표가 없다', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 100000, previousTotal: 100000)));

      expect(find.text('변동 없음'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('비교 기간 매출이 0원이면 퍼센트 대신 "비교할 매출 없음"이다', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 50000, previousTotal: 0)));

      expect(find.text('비교할 매출 없음'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('건수가 0이면 건당 평균은 "-"다 (0원이 아니다)', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 0, count: 0, previousTotal: 0)));

      expect(find.text('-'), findsOneWidget);
      expect(find.text('0원'), findsOneWidget); // 총 매출은 0원
      expect(find.text('0건'), findsOneWidget);
    });

    testWidgets('아주 큰 금액이나 좁은 화면에서도 줄바꿈/넘침 없이 한 줄에 맞춘다', (tester) async {
      await pumpIn(tester, StatsSummaryCard(data: sampleStatsData(total: 1234567890, count: 9999)), width: 220);

      expect(tester.takeException(), isNull);
      expect(find.text('1,234,567,890원'), findsOneWidget);
    });
  });
}
