import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/home/home_page.dart';
import 'package:hairdesk/features/menu/menu.dart';
import 'package:hairdesk/features/reservation/reservation.dart';

import '../../support/fakes.dart';

/// 홈(메인) 화면 테스트. 시계를 2026-10-01 11:00(서울)로 고정해서 "30분 뒤" 같은 글자를 검증한다.
final _now = DateTime.parse('2026-10-01T11:00:00+09:00');

class _Harness {
  _Harness({List<Reservation>? initial, DateTime Function()? clock})
      : clock = clock ?? (() => _now),
        customers = FakeCustomerRepository([customerOf(1, '김민지', '01012345678')]),
        menus = FakeMenuRepository([menuOf(1, '커트')]) {
    // 예약 등록 응답에 이름을 채우려면 가짜 예약 저장소가 고객/메뉴 목록을 알아야 한다.
    reservations = FakeReservationRepository(
      initial ?? _defaultReservations(),
      customers: customers.customers,
      menus: menus.menus,
    );
    sales = FakeSaleRepository(
      reservations: reservations,
      ledger: [
        (date: DateTime(2026, 9, 30), amount: 99999), // 지난달: 이번 달 합계에 들어가면 안 된다
        (date: DateTime(2026, 10, 1), amount: 20000),
        (date: DateTime(2026, 10, 1), amount: 18000),
        (date: DateTime(2026, 10, 15), amount: 50000),
        (date: DateTime(2026, 11, 1), amount: 77777), // 다음 달
      ],
    );
  }

  final DateTime Function() clock;
  late final FakeReservationRepository reservations;
  final FakeCustomerRepository customers;
  final FakeMenuRepository menus;
  late final FakeSaleRepository sales;

  int scheduleOpened = 0;
  int statsOpened = 0;
  int menusOpened = 0;

  static List<Reservation> _defaultReservations() => [
        // 09:00~10:00 "예약" 상태인데 지금(11:00)보다 이전 → 처리 안 된 예약
        reservationOf(1, '김민지', '커트', '2026-10-01T09:00:00+09:00', '2026-10-01T10:00:00+09:00'),
        reservationOf(2, '박서준', '커트', '2026-10-01T10:00:00+09:00', '2026-10-01T11:00:00+09:00',
            status: ReservationStatus.completed),
        // 지금부터 30분 뒤 → "다음 예약"
        reservationOf(3, '이하늘', '펌', '2026-10-01T11:30:00+09:00', '2026-10-01T13:30:00+09:00',
            memo: '뿌리 볼륨'),
        reservationOf(4, '최유리', '염색', '2026-10-01T15:00:00+09:00', '2026-10-01T16:00:00+09:00'),
        reservationOf(5, '한지우', '커트', '2026-10-01T17:00:00+09:00', '2026-10-01T18:00:00+09:00',
            status: ReservationStatus.cancelled),
      ];

  Future<void> pump(WidgetTester tester, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 2400); // 홈은 길어서 키 큰 화면에서 본다
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        reservationRepository: reservations,
        customerRepository: customers,
        menuRepository: menus,
        saleRepository: sales,
        onOpenSchedule: () => scheduleOpened++,
        onOpenStats: () => statsOpened++,
        onOpenMenus: () => menusOpened++,
        clock: clock,
      ),
    ));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('오늘 날짜와 예약 현황, 오늘/이번 달 매출을 보여준다', (tester) async {
    await _Harness().pump(tester);

    expect(find.text('2026년 10월 1일 (목)'), findsOneWidget);
    expect(find.text('남은 예약 2건 · 완료 1건'), findsOneWidget); // 남은 = 아직 안 끝난 "예약" 2건(이하늘, 최유리)
    expect(find.text('오늘 매출'), findsOneWidget);
    expect(find.text('38,000원'), findsOneWidget);
    expect(find.text('2건'), findsOneWidget);
    expect(find.text('이번 달 매출'), findsOneWidget);
    expect(find.text('88,000원'), findsOneWidget); // 9/30, 11/1은 빠지고 10월분만
    expect(find.text('3건'), findsOneWidget);
  });

  testWidgets('다음 예약 카드에 시간까지 남은 시간이 나온다', (tester) async {
    await _Harness().pump(tester);

    expect(find.text('다음 예약'), findsOneWidget);
    expect(find.text('30분 뒤'), findsOneWidget);
    expect(find.text('메모: 뿌리 볼륨'), findsOneWidget);
    // 카드와 아래 "오늘 일정" 목록에 한 번씩
    expect(find.text('이하늘 · 펌'), findsNWidgets(2));
  });

  testWidgets('지금 진행 중인 예약이 다음 예약이면 "진행 중"으로 보인다', (tester) async {
    final h = _Harness(clock: () => DateTime.parse('2026-10-01T11:40:00+09:00'));
    await h.pump(tester);

    expect(find.text('진행 중'), findsOneWidget);
  });

  testWidgets('시간이 지났는데 처리 안 된 예약이 있으면 알려주고, 누르면 그 예약이 열린다', (tester) async {
    await _Harness().pump(tester);

    expect(find.text('처리하지 않은 지난 예약이 1건 있어요'), findsOneWidget);

    await tester.tap(find.text('처리하지 않은 지난 예약이 1건 있어요'));
    await tester.pumpAndSettle();

    expect(find.text('김민지'), findsWidgets); // 상세 시트의 고객 이름
    expect(find.text('결제하기'), findsOneWidget);
  });

  testWidgets('처리 안 된 예약이 없으면 알림이 나오지 않는다', (tester) async {
    final h = _Harness(initial: [
      reservationOf(1, '이하늘', '펌', '2026-10-01T11:30:00+09:00', '2026-10-01T13:30:00+09:00'),
    ]);
    await h.pump(tester);

    expect(find.textContaining('처리하지 않은'), findsNothing);
  });

  testWidgets('"상세 · 결제"를 누르면 예약 시트가 열리고, 결제하면 홈이 새로고침된다', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await tester.tap(find.text('상세 · 결제'));
    await tester.pumpAndSettle();
    expect(find.text('결제하기'), findsOneWidget);

    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('결제 등록'));
    await tester.pumpAndSettle();

    expect(h.sales.created.single['reservationId'], 3);
    expect(find.textContaining('결제가 등록되었어요'), findsOneWidget);
    expect(find.text('남은 예약 1건 · 완료 2건'), findsOneWidget); // 이하늘이 완료로 옮겨 감
    expect(find.text('다음 예약'), findsOneWidget); // 다음은 최유리로 바뀜
    expect(find.text('최유리 · 염색'), findsNWidgets(2));
  });

  testWidgets('남은 예약이 없으면 안내와 예약 추가 버튼을 보여준다', (tester) async {
    final h = _Harness(initial: [
      reservationOf(1, '박서준', '커트', '2026-10-01T09:00:00+09:00', '2026-10-01T10:00:00+09:00',
          status: ReservationStatus.completed),
    ]);
    await h.pump(tester);

    expect(find.text('남은 예약이 없어요'), findsOneWidget);
    expect(find.text('남은 예약 0건 · 완료 1건'), findsOneWidget);
  });

  testWidgets('예약이 하나도 없는 날', (tester) async {
    final h = _Harness(initial: []);
    await h.pump(tester);

    expect(find.text('오늘은 예약이 없어요'), findsOneWidget); // 요약
    expect(find.text('오늘은 예약이 없어요.'), findsOneWidget); // 일정 영역
    expect(find.text('남은 예약이 없어요'), findsOneWidget); // 다음 예약 자리
  });

  testWidgets('오늘 일정은 5건까지만 보이고 나머지는 "더 보기"로 알려준다', (tester) async {
    final h = _Harness(initial: [
      for (var i = 0; i < 6; i++)
        reservationOf(i + 1, '고객${i + 1}', '커트', '2026-10-01T${12 + i}:00:00+09:00',
            '2026-10-01T${12 + i}:30:00+09:00'),
    ]);
    await h.pump(tester);

    expect(find.text('외 1건 더 보기'), findsOneWidget);
    expect(find.text('고객6 · 커트'), findsNothing);
  });

  testWidgets('아직 없는 기능의 버튼은 "준비 중" 표시가 있고, 누르면 안내만 한다', (tester) async {
    await _Harness().pump(tester);

    expect(find.text('준비 중'), findsNWidgets(3)); // 매출 등록, 고객 관리, 휴무일 설정 (매출·통계는 이제 동작한다)

    await tester.tap(find.text('고객 관리'));
    await tester.pump();

    expect(find.text('고객 관리 기능은 준비 중이에요'), findsOneWidget);
  });

  testWidgets('폰 폭(375)에서도 빠른 실행 칸의 아이콘, 이름, "준비 중"이 잘리지 않는다 (넘침 에러가 없다)', (tester) async {
    await _Harness().pump(tester, width: 375);

    // 칸 안의 내용이 칸보다 크면 Flutter가 "RenderFlex overflowed" 에러를 던진다. 그게 없어야 한다.
    expect(tester.takeException(), isNull);
    for (final label in ['예약 추가', '매출 등록', '고객 관리', '매출·통계', '시술 메뉴', '휴무일 설정']) {
      final tile = find.ancestor(of: find.text(label), matching: find.byType(InkWell));
      expect(tester.getSize(tile).height, 92, reason: '$label 칸 높이');
    }
    expect(find.text('준비 중'), findsNWidgets(3));
  });

  testWidgets('"시술 메뉴", "매출·통계", "전체 보기"는 탭 이동을 부탁한다', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await tester.tap(find.text('시술 메뉴'));
    await tester.tap(find.text('매출·통계'));
    await tester.tap(find.text('전체 보기'));

    expect(h.menusOpened, 1);
    expect(h.statsOpened, 1);
    expect(h.scheduleOpened, 1);
  });

  testWidgets('"매출·통계" 버튼에는 더 이상 "준비 중" 표시가 없다', (tester) async {
    await _Harness().pump(tester);

    final statsTile = find.ancestor(of: find.text('매출·통계'), matching: find.byType(InkWell));
    expect(find.descendant(of: statsTile, matching: find.text('준비 중')), findsNothing);
  });

  testWidgets('"예약 추가"는 오늘 날짜로 예약 폼을 연다', (tester) async {
    await _Harness().pump(tester);

    await tester.tap(find.text('예약 추가').first); // 빠른 실행 칸
    await tester.pumpAndSettle();

    expect(find.text('탭해서 고객 선택'), findsOneWidget);
    expect(find.text('2026년 10월 1일 (목)'), findsOneWidget); // 폼의 날짜 칸 = 오늘
  });

  testWidgets('예약을 추가하고 돌아오면 홈이 새로고침되어 새 예약이 보인다', (tester) async {
    final h = _Harness(initial: []);
    await h.pump(tester);

    await tester.tap(find.text('예약 추가').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('탭해서 고객 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('김민지'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Menu>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('커트 · 1시간').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('예약을 추가했어요'), findsOneWidget);
    expect(find.text('김민지 · 커트'), findsWidgets);
  });

  testWidgets('서버 오류면 안내와 다시 시도 버튼을 보여주고, 복구되면 다시 불러온다', (tester) async {
    final h = _Harness();
    h.sales.failOnSummary = ApiException(500, '서버 오류');
    await h.pump(tester);

    expect(find.text('서버 오류'), findsOneWidget);

    h.sales.failOnSummary = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 매출'), findsOneWidget);
  });
}
