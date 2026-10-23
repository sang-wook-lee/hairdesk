import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/home/home_shell.dart';

import '../../support/fakes.dart';

void main() {
  late FakeReservationRepository reservations;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    reservations = FakeReservationRepository([]);
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        reservationRepository: reservations,
        customerRepository: FakeCustomerRepository([]),
        menuRepository: FakeMenuRepository([]),
        saleRepository: FakeSaleRepository(),
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
}
