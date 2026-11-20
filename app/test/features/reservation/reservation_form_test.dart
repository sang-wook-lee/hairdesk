import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/menu/menu.dart';
import 'package:hairdesk/features/staff/staff.dart';
import 'package:hairdesk/features/reservation/schedule_page.dart';

import '../../support/fakes.dart';

/// 예약 추가 흐름 테스트. 일정 화면에서 "예약 추가"를 눌러 폼을 열고 끝까지 진행한다.
class _Harness {
  /// [staffList]: 근무 중인 직원. 기본은 원장 1명(혼자 일하는 매장)이다.
  _Harness({List<Staff>? staffList})
      : staff = FakeStaffRepository(staffList ?? [staffOf(1, '원장', '원장')]),
        customers = FakeCustomerRepository([
          customerOf(1, '김민지', '01012345678', memo: '두피 민감'),
          customerOf(2, '이하늘', '01099990000'),
        ]),
        menus = FakeMenuRepository([
          menuOf(1, '커트'),
          menuOf(2, '펌', price: 80000, minutes: 150),
          menuOf(3, '옛날 염색', active: false),
        ]) {
    reservations = FakeReservationRepository(
      [],
      customers: customers.customers,
      menus: menus.menus,
    );
  }

  final FakeCustomerRepository customers;
  final FakeMenuRepository menus;
  final FakeStaffRepository staff;
  late final FakeReservationRepository reservations;

  Future<void> pump(WidgetTester tester) async {
    // 폼이 길어서 기본 화면 높이에선 저장 버튼이 접힌다. 테스트용 화면을 크게 잡는다.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: SchedulePage(
        repository: reservations,
        customerRepository: customers,
        menuRepository: menus,
        staffRepository: staff,
        saleRepository: FakeSaleRepository(),
        initialDate: DateTime(2026, 10, 1),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('예약 추가'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCustomer(WidgetTester tester, String name) async {
    await tester.tap(find.text('탭해서 고객 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> chooseStaff(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<Staff>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<Menu>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('고객과 메뉴를 고르고 저장하면 예약이 만들어지고 일정에 나타난다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openForm(tester);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await tester.enterText(find.widgetWithText(TextFormField, '메모 (선택)'), '뒷머리 짧게');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // 서버로 간 값: 일정에서 보던 날짜(10/1) + 기본 시간(10:00)이 서울 오프셋과 함께 간다
    expect(h.reservations.created.single, {
      'customerId': 1,
      'menuId': 1,
      'staffId': 1, // 근무 중인 직원이 원장 1명뿐이라 자동으로 지정됐다
      'startAt': '2026-10-01T10:00:00+09:00',
      'memo': '뒷머리 짧게',
    });
    // 폼이 닫히고 일정 화면에 새 예약이 보인다
    expect(find.text('김민지 · 커트'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
  });

  testWidgets('메뉴를 고르면 종료 시각 미리보기가 나온다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openForm(tester);

    expect(find.textContaining('예상:'), findsNothing); // 메뉴를 고르기 전에는 모른다

    await h.chooseMenu(tester, '펌 · 2시간 30분 · 80,000원');

    expect(find.text('예상: 10:00 ~ 12:30 (2시간 30분)'), findsOneWidget);
  });

  testWidgets('판매 중지된 메뉴는 선택지에 나오지 않는다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Menu>));
    await tester.pumpAndSettle();

    expect(find.textContaining('커트'), findsWidgets);
    expect(find.textContaining('옛날 염색'), findsNothing);
  });

  testWidgets('고객과 메뉴를 안 고르고 저장하면 안내하고 서버로 보내지 않는다', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.openForm(tester);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('고객을 선택해 주세요'), findsOneWidget);
    expect(find.text('메뉴를 선택해 주세요'), findsOneWidget);
    expect(h.reservations.created, isEmpty);
  });

  testWidgets('시간이 겹쳐 서버가 거절하면 그 메시지를 폼에 보여주고 폼에 머문다', (tester) async {
    final h = _Harness();
    h.reservations.failOnCreate = ApiException(409, '해당 시간에 이미 예약이 있습니다.');
    await h.pump(tester);
    await h.openForm(tester);

    await h.chooseCustomer(tester, '이하늘');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('해당 시간에 이미 예약이 있습니다.'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget); // 폼이 그대로 남아 있다 → 시간을 고쳐 다시 시도할 수 있다
    expect(find.text('예약 추가'), findsOneWidget); // 폼 제목만 있고 일정 화면의 버튼은 가려져 있다
  });

  testWidgets('서버에 연결할 수 없으면 연결 안내를 보여주고 폼에 머문다', (tester) async {
    final h = _Harness();
    h.reservations.failOnCreate = Exception('connection refused'); // ApiException이 아닌 네트워크 오류
    await h.pump(tester);
    await h.openForm(tester);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });

  // ---- 담당자 (ADR 0011) ----

  testWidgets('근무 중인 직원이 1명이면 담당자 칸이 없고, 그 직원의 번호가 서버로 간다', (tester) async {
    final h = _Harness(staffList: [staffOf(7, '이지수', '실장')]);
    await h.pump(tester);
    await h.openForm(tester);

    expect(find.byType(DropdownButtonFormField<Staff>), findsNothing);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(h.reservations.created.single['staffId'], 7);
  });

  testWidgets('근무 중인 직원이 2명 이상이면 담당자를 고르고, 고른 직원의 번호가 서버로 간다', (tester) async {
    final h = _Harness(staffList: [staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')]);
    await h.pump(tester);
    await h.openForm(tester);

    expect(find.byType(DropdownButtonFormField<Staff>), findsOneWidget);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await h.chooseStaff(tester, '이지수 (#2) · 실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(h.reservations.created.single['staffId'], 2);
  });

  testWidgets('이름과 직책이 같은 직원도 번호로 구별되어 목록에 둘 다 나온다', (tester) async {
    final h = _Harness(staffList: [staffOf(2, '이지수', '실장'), staffOf(5, '이지수', '실장')]);
    await h.pump(tester);
    await h.openForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Staff>));
    await tester.pumpAndSettle();

    expect(find.text('이지수 (#2) · 실장'), findsOneWidget);
    expect(find.text('이지수 (#5) · 실장'), findsOneWidget);
  });

  testWidgets('직원이 2명 이상인데 담당자를 안 고르면 안내하고 서버로 보내지 않는다 (기본값 없음)', (tester) async {
    final h = _Harness(staffList: [staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')]);
    await h.pump(tester);
    await h.openForm(tester);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('담당자를 선택해 주세요'), findsOneWidget);
    expect(h.reservations.created, isEmpty);
  });

  testWidgets('근무 중인 직원이 없으면 안내하고 저장할 수 없다', (tester) async {
    final h = _Harness(staffList: []);
    await h.pump(tester);
    await h.openForm(tester);

    expect(find.textContaining('근무 중인 직원이 없어요'), findsOneWidget);
    expect(find.textContaining('근무를 재개해 주세요'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNull); // 저장 버튼이 비활성이다
  });

  testWidgets('직원 목록을 불러오지 못하면 오류와 "다시 시도"가 나오고, 복구되면 저장할 수 있다', (tester) async {
    final h = _Harness();
    h.staff.failOnFetch = ApiException(500, '서버 오류');
    await h.pump(tester);
    await h.openForm(tester);

    expect(find.text('서버 오류'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    h.staff.failOnFetch = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('서버 오류'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('그 직원의 시간이 이미 차서 서버가 거절하면, 어느 직원인지 담긴 메시지를 그대로 보여준다', (tester) async {
    final h = _Harness(staffList: [staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')]);
    h.reservations.failOnCreate = ApiException(409, '이지수(#2)은(는) 해당 시간에 이미 예약이 있습니다.');
    await h.pump(tester);
    await h.openForm(tester);

    await h.chooseCustomer(tester, '김민지');
    await h.chooseMenu(tester, '커트 · 1시간 · 20,000원');
    await h.chooseStaff(tester, '이지수 (#2) · 실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('이지수(#2)은(는) 해당 시간에 이미 예약이 있습니다.'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget); // 폼에 머물러서 다른 직원이나 시간으로 다시 시도할 수 있다
  });
}
