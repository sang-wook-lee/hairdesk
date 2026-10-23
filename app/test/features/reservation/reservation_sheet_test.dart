import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/reservation/reservation.dart';
import 'package:hairdesk/features/reservation/schedule_page.dart';
import 'package:hairdesk/features/sales/sale.dart';

import '../../support/fakes.dart';

/// 일정 화면에서 예약을 탭해 상세 시트를 열고 상태를 바꾸는 흐름 테스트.
class _Harness {
  _Harness({bool knownMenu = true}) {
    reservations = FakeReservationRepository([
      reservationOf(1, '김민지', '커트', '2026-10-01T10:00:00+09:00', '2026-10-01T11:00:00+09:00',
          memo: '뒷머리 짧게'),
      reservationOf(2, '이하늘', '펌', '2026-10-01T12:00:00+09:00', '2026-10-01T14:00:00+09:00',
          status: ReservationStatus.completed),
    ]);
    sales = FakeSaleRepository(reservations: reservations);
    // 메뉴 1번(커트, 정가 20,000원). knownMenu=false면 가격을 알 수 없는 상황을 만든다.
    menus = FakeMenuRepository(knownMenu ? [menuOf(1, '커트')] : []);
  }

  late final FakeReservationRepository reservations;
  late final FakeSaleRepository sales;
  late final FakeMenuRepository menus;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: SchedulePage(
        repository: reservations,
        customerRepository: FakeCustomerRepository([]),
        menuRepository: menus,
        saleRepository: sales,
        initialDate: DateTime(2026, 10, 1),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 김민지 예약을 탭해서 시트를 연다.
  Future<void> openSheet(WidgetTester tester, {String tile = '김민지 · 커트'}) async {
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }
}

/// 시트에 있는 버튼(OutlinedButton)과 대화상자의 확인 버튼(FilledButton)이 같은 글자라서 종류로 구분한다.
Finder _sheetButton(String label) => find.widgetWithText(OutlinedButton, label);
Finder _dialogConfirm(String label) => find.widgetWithText(FilledButton, label);

void main() {
  testWidgets('예약을 탭하면 고객, 메뉴, 시간, 메모와 동작 버튼이 보인다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    expect(find.text('010-1234-5678'), findsOneWidget);
    expect(find.text('2026년 10월 1일 (목)  10:00 ~ 11:00'), findsOneWidget);
    expect(find.text('메모: 뒷머리 짧게'), findsOneWidget);
    expect(find.text('결제하기'), findsOneWidget);
    expect(_sheetButton('시간 변경'), findsOneWidget);
    expect(_sheetButton('예약 취소'), findsOneWidget);
    expect(_sheetButton('노쇼'), findsOneWidget);
  });

  testWidgets('이미 완료된 예약은 정보만 보이고 바꿀 수 없다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester, tile: '이하늘 · 펌');

    expect(find.text('완료 상태의 예약은 바꿀 수 없어요.'), findsOneWidget);
    expect(find.text('결제하기'), findsNothing);
    expect(_sheetButton('예약 취소'), findsNothing);
  });

  testWidgets('예약 취소: 확인하면 취소되고 일정에 반영되며 안내가 뜬다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('예약 취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('김민지님의 예약을 취소할까요?'), findsOneWidget);
    await tester.tap(_dialogConfirm('예약 취소'));
    await tester.pumpAndSettle();

    expect(h.reservations.changes, ['cancel:1']);
    expect(find.text('예약을 취소했어요'), findsOneWidget); // 안내(SnackBar)
    expect(find.text('취소'), findsOneWidget); // 일정 목록의 상태 칩
    expect(find.text('결제하기'), findsNothing); // 시트는 닫혔다
  });

  testWidgets('예약 취소: "돌아가기"를 누르면 아무것도 바뀌지 않는다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('예약 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();

    expect(h.reservations.changes, isEmpty);
    expect(find.text('결제하기'), findsOneWidget); // 시트는 그대로 열려 있다
  });

  testWidgets('노쇼 처리', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('노쇼'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogConfirm('노쇼 처리'));
    await tester.pumpAndSettle();

    expect(h.reservations.changes, ['no-show:1']);
    expect(find.text('노쇼로 처리했어요'), findsOneWidget);
    expect(find.text('노쇼'), findsOneWidget); // 상태 칩
  });

  testWidgets('결제: 정가가 미리 채워지고, 금액을 깎으면 할인액을 보여주며, 등록하면 예약이 완료된다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();

    final amountField = find.widgetWithText(TextFormField, '받은 금액 (원)');
    expect(tester.widget<TextFormField>(amountField).controller!.text, '20000'); // 메뉴 정가가 기본값
    expect(find.text('정가 20,000원'), findsOneWidget);

    await tester.enterText(amountField, '18000');
    await tester.pump();
    expect(find.text('정가 20,000원 · 할인 2,000원'), findsOneWidget);

    await tester.tap(find.text('현금'));
    await tester.pump();
    await tester.tap(find.text('결제 등록'));
    await tester.pumpAndSettle();

    expect(h.sales.created.single, {
      'reservationId': 1,
      'amount': 18000,
      'method': PaymentMethod.cash,
      'memo': null,
    });
    expect(find.text('결제가 등록되었어요 (18,000원)'), findsOneWidget);
    expect(find.text('완료'), findsNWidgets(2)); // 원래 완료였던 이하늘 + 방금 결제한 김민지
  });

  testWidgets('결제: 금액을 비우면 안내하고 서버로 보내지 않는다 (0원은 허용)', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '받은 금액 (원)'), '');
    await tester.tap(find.text('결제 등록'));
    await tester.pumpAndSettle();

    expect(find.text('금액을 입력해 주세요 (0원도 가능)'), findsOneWidget);
    expect(h.sales.created, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, '받은 금액 (원)'), '0'); // 서비스로 해 준 경우
    await tester.tap(find.text('결제 등록'));
    await tester.pumpAndSettle();

    expect(h.sales.created.single['amount'], 0);
  });

  testWidgets('결제: 메뉴 가격을 알 수 없으면 금액 칸이 비어 있고 직접 입력한다', (tester) async {
    final h = _Harness(knownMenu: false);
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, '받은 금액 (원)')).controller!.text, '');
    expect(find.textContaining('정가'), findsNothing);
  });

  testWidgets('결제: 서버가 거절하면 시트 안에 이유를 보여주고 시트는 열려 있다', (tester) async {
    final h = _Harness();
    h.sales.failOnCreate = ApiException(409, '이미 결제가 등록된 예약입니다. id=1');
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('결제 등록'));
    await tester.pumpAndSettle();

    expect(find.text('이미 결제가 등록된 예약입니다. id=1'), findsOneWidget);
    expect(find.text('결제하기'), findsOneWidget); // 시트가 그대로
    expect(find.text('결제가 등록되었어요 (20,000원)'), findsNothing);
  });

  testWidgets('서버에 연결할 수 없으면 취소가 실패하고 연결 안내를 보여준다', (tester) async {
    final h = _Harness();
    h.reservations.failOnChange = Exception('connection refused');
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('예약 취소'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogConfirm('예약 취소'));
    await tester.pumpAndSettle();

    expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
    expect(find.text('결제하기'), findsOneWidget);
  });

  testWidgets('시간 변경: 날짜와 시간을 고르면 서울 시각으로 서버에 보낸다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('시간 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // 날짜 선택(기본값 = 현재 예약 날짜)
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // 시간 선택(기본값 = 현재 예약 시간)
    await tester.pumpAndSettle();

    expect(h.reservations.changes, ['reschedule:1:2026-10-01T10:00:00+09:00']);
    expect(find.text('예약 시간을 바꿨어요'), findsOneWidget);
  });

  testWidgets('시간 변경이 겹쳐서 거절되면 그 메시지를 시트에 보여준다', (tester) async {
    final h = _Harness();
    h.reservations.failOnChange = ApiException(409, '해당 시간에 이미 예약이 있습니다.');
    await h.pump(tester);
    await h.openSheet(tester);

    await tester.tap(_sheetButton('시간 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('해당 시간에 이미 예약이 있습니다.'), findsOneWidget);
    expect(find.text('결제하기'), findsOneWidget);
  });
}
