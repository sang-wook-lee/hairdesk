import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/sales/sale.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/stats_calculations.dart';
import 'package:hairdesk/features/stats/widgets/counts_cards.dart';
import 'package:hairdesk/features/stats/widgets/menu_ranking.dart';
import 'package:hairdesk/features/stats/widgets/payment_method_bar.dart';

Future<void> pumpIn(WidgetTester tester, Widget child, {double width = 400}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, child: child)))),
  ));
}

MenuSales menu(int id, String name, int amount, int count) =>
    MenuSales(menuId: id, menuName: name, totalAmount: amount, count: count);

void main() {
  group('PaymentMethodBar', () {
    // 서버 실제 값: 카드 713,000(14건) / 계좌이체 468,000(7건) / 현금 441,000(9건)
    final shares = paymentMethodShares(const [
      MethodTotal(method: PaymentMethod.card, totalAmount: 713000, count: 14),
      MethodTotal(method: PaymentMethod.cash, totalAmount: 441000, count: 9),
      MethodTotal(method: PaymentMethod.transfer, totalAmount: 468000, count: 7),
    ]);

    testWidgets('범례에 수단별 퍼센트, 금액, 건수를 금액이 큰 순서로 보여준다', (tester) async {
      await pumpIn(tester, PaymentMethodBar(shares: shares));

      expect(find.text('카드'), findsOneWidget);
      expect(find.text('44%'), findsOneWidget);
      expect(find.text('713,000원 · 14건'), findsOneWidget);
      expect(find.text('29%'), findsOneWidget);
      expect(find.text('27%'), findsOneWidget);

      // 위에서 아래로 카드 → 계좌이체 → 현금
      final cardY = tester.getTopLeft(find.text('카드')).dy;
      final transferY = tester.getTopLeft(find.text('계좌이체')).dy;
      final cashY = tester.getTopLeft(find.text('현금')).dy;
      expect(cardY, lessThan(transferY));
      expect(transferY, lessThan(cashY));
    });

    testWidgets('막대의 칸 너비는 퍼센트가 아니라 금액 비율대로다', (tester) async {
      await pumpIn(tester, PaymentMethodBar(shares: shares));

      final card = tester.getSize(find.byKey(const ValueKey('segment-CARD'))).width;
      final cash = tester.getSize(find.byKey(const ValueKey('segment-CASH'))).width;
      final transfer = tester.getSize(find.byKey(const ValueKey('segment-TRANSFER'))).width;

      expect(card / cash, closeTo(713000 / 441000, 0.01));
      expect(transfer / cash, closeTo(468000 / 441000, 0.01));
      expect(card + cash + transfer, closeTo(400, 0.5)); // 막대 전체 폭을 꽉 채운다
    });

    testWidgets('막대 칸은 실제로 눈에 보이는 높이를 가진다 (너비만 있고 높이가 0인 보이지 않는 막대 방지)', (tester) async {
      await pumpIn(tester, PaymentMethodBar(shares: shares));

      final height = tester.getSize(find.byKey(const ValueKey('segment-CARD'))).height;

      expect(height, 14);
    });

    testWidgets('금액이 0원인 수단은 막대 칸을 만들지 않지만 범례에는 남는다', (tester) async {
      final withZero = [
        const MethodShare(method: PaymentMethod.card, totalAmount: 50000, count: 2, percent: 100),
        const MethodShare(method: PaymentMethod.cash, totalAmount: 0, count: 0, percent: 0),
      ];
      await pumpIn(tester, PaymentMethodBar(shares: withZero));

      expect(find.byKey(const ValueKey('segment-CASH')), findsNothing);
      expect(find.text('현금'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('결제 내역이 없으면 안내 문구', (tester) async {
      await pumpIn(tester, const PaymentMethodBar(shares: []));

      expect(find.text('결제 내역이 없어요'), findsOneWidget);
    });

    testWidgets('좁은 화면(폭 260)에서도 넘치지 않는다', (tester) async {
      await pumpIn(tester, PaymentMethodBar(shares: shares), width: 260);

      expect(tester.takeException(), isNull);
    });
  });

  group('MenuRanking', () {
    final menus = [
      menu(4, '셋팅 펌', 546000, 5),
      menu(2, '여성 커트', 300000, 12),
      menu(1, '남성 커트', 150000, 10),
    ];

    testWidgets('순위, 메뉴 이름, 금액, 건수를 보여준다', (tester) async {
      await pumpIn(tester, MenuRanking(menus: menus));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('셋팅 펌'), findsOneWidget);
      expect(find.text('546,000원'), findsOneWidget);
      expect(find.text('5건'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('남성 커트'), findsOneWidget);
    });

    testWidgets('각 줄의 막대는 1위를 100%로 한 상대 크기다', (tester) async {
      await pumpIn(tester, MenuRanking(menus: menus));

      final values = tester
          .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .map((p) => p.value)
          .toList();

      expect(values[0], 1.0);
      expect(values[1], closeTo(300000 / 546000, 0.0001));
      expect(values[2], closeTo(150000 / 546000, 0.0001));
    });

    testWidgets('5개를 넘으면 나머지는 "그 외 N개 메뉴"로 합쳐서 보여준다', (tester) async {
      final seven = [
        for (var i = 1; i <= 7; i++) menu(i, '메뉴$i', (8 - i) * 100000, i), // 70만, 60만 ... 10만
      ];
      await pumpIn(tester, MenuRanking(menus: seven));

      expect(find.text('메뉴5'), findsOneWidget);
      expect(find.text('메뉴6'), findsNothing); // 6, 7위는 묶여서 보이지 않는다
      expect(find.text('그 외 2개 메뉴'), findsOneWidget);
      expect(find.text('300,000원 · 13건'), findsOneWidget); // (20만 + 10만), (6건 + 7건)
    });

    testWidgets('팔린 메뉴가 없으면 안내 문구', (tester) async {
      await pumpIn(tester, const MenuRanking(menus: []));

      expect(find.text('이 달에 팔린 메뉴가 없어요'), findsOneWidget);
    });

    testWidgets('메뉴가 하나뿐이어도 정상이고, 좁은 화면에서도 넘치지 않는다', (tester) async {
      await pumpIn(tester, MenuRanking(menus: [menu(1, '아주아주 긴 이름의 프리미엄 두피 클리닉 케어 패키지', 90000, 1)]), width: 240);

      expect(tester.takeException(), isNull);
      expect(find.text('그 외', skipOffstage: false), findsNothing);
    });
  });

  group('CustomerStatsBody', () {
    testWidgets('전체 고객 수와 신규/재방문 인원을 보여준다', (tester) async {
      await pumpIn(
        tester,
        const CustomerStatsBody(stats: CustomerStats(totalCustomers: 12, newCustomers: 4, returningCustomers: 8)),
      );

      expect(find.text('12명'), findsOneWidget);
      expect(find.text('신규 4명'), findsOneWidget);
      expect(find.text('재방문 8명'), findsOneWidget);
    });

    testWidgets('신규/재방문 막대는 눈에 보이는 높이를 가진다', (tester) async {
      await pumpIn(
        tester,
        const CustomerStatsBody(stats: CustomerStats(totalCustomers: 12, newCustomers: 4, returningCustomers: 8)),
      );

      final bars = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).length;
      final heights = [
        for (final e in tester.elementList(find.descendant(of: find.byType(CustomerStatsBody), matching: find.byType(ColoredBox))))
          (e.renderObject! as RenderBox).size.height,
      ];

      expect(bars, greaterThanOrEqualTo(2));
      expect(heights.where((h) => h == 12).length, 2); // 신규 칸, 재방문 칸
    });

    testWidgets('한쪽이 0명이어도(전원 신규) 막대가 깨지지 않는다', (tester) async {
      await pumpIn(
        tester,
        const CustomerStatsBody(stats: CustomerStats(totalCustomers: 3, newCustomers: 3, returningCustomers: 0)),
      );

      expect(find.text('재방문 0명'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방문한 고객이 없으면 안내 문구', (tester) async {
      await pumpIn(
        tester,
        const CustomerStatsBody(stats: CustomerStats(totalCustomers: 0, newCustomers: 0, returningCustomers: 0)),
      );

      expect(find.text('이 달에 방문한 고객이 없어요'), findsOneWidget);
    });
  });

  group('ReservationStatsBody', () {
    testWidgets('상태별 건수와 노쇼율(소수점 한 자리)과 계산식을 보여준다', (tester) async {
      await pumpIn(
        tester,
        const ReservationStatsBody(
          stats: ReservationStats(booked: 10, completed: 30, cancelled: 1, noShow: 3, noShowRate: 0.09090909090909091),
        ),
      );

      expect(find.text('30'), findsOneWidget); // 완료
      expect(find.text('10'), findsOneWidget); // 예정
      expect(find.text('1'), findsOneWidget); // 취소
      expect(find.text('3'), findsOneWidget); // 노쇼
      expect(find.text('9.1%'), findsOneWidget);
      expect(find.text('노쇼 ÷ (완료 + 노쇼)'), findsOneWidget);
    });

    testWidgets('결과가 난 예약이 없으면 노쇼율은 0.0%', (tester) async {
      await pumpIn(
        tester,
        const ReservationStatsBody(
          stats: ReservationStats(booked: 0, completed: 0, cancelled: 0, noShow: 0, noShowRate: 0),
        ),
      );

      expect(find.text('0.0%'), findsOneWidget);
    });
  });
}
