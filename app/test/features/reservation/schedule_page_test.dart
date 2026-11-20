import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/core/kst.dart';
import 'package:hairdesk/features/reservation/reservation.dart';
import 'package:hairdesk/features/reservation/schedule_page.dart';

import '../../support/fakes.dart';

Future<FakeReservationRepository> _pump(
  WidgetTester tester,
  List<Reservation> reservations, {
  DateTime? date,
}) async {
  final repo = FakeReservationRepository(reservations);
  await tester.pumpWidget(MaterialApp(
    home: SchedulePage(
      repository: repo,
      customerRepository: FakeCustomerRepository([]),
      menuRepository: FakeMenuRepository([]),
      staffRepository: FakeStaffRepository([staffOf(1, '원장', '원장')]),
      saleRepository: FakeSaleRepository(),
      initialDate: date ?? DateTime(2026, 10, 1),
    ),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('그날의 예약을 시간, 고객, 메뉴, 상태와 함께 보여준다', (tester) async {
    await _pump(tester, [
      reservationOf(1, '김민지', '커트', '2026-10-01T14:00:00+09:00', '2026-10-01T15:00:00+09:00',
          memo: '두피 민감'),
      reservationOf(2, '이하늘', '펌', '2026-10-01T16:00:00+09:00', '2026-10-01T18:00:00+09:00',
          status: ReservationStatus.completed),
    ]);

    expect(find.text('2026년 10월 1일 (목)'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('김민지 · 커트'), findsOneWidget);
    expect(find.text('두피 민감'), findsOneWidget);
    expect(find.text('예약'), findsOneWidget); // 상태 칩
    expect(find.text('이하늘 · 펌'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });

  testWidgets('다른 날짜의 예약은 보이지 않는다', (tester) async {
    await _pump(tester, [
      reservationOf(1, '김민지', '커트', '2026-10-02T10:00:00+09:00', '2026-10-02T11:00:00+09:00'),
    ]);

    expect(find.text('김민지 · 커트'), findsNothing);
    expect(find.text('이 날은 예약이 없어요.'), findsOneWidget);
  });

  testWidgets('다음날/전날 버튼으로 날짜를 옮기면 그 날짜로 다시 불러온다', (tester) async {
    final repo = await _pump(tester, [
      reservationOf(1, '김민지', '커트', '2026-10-02T10:00:00+09:00', '2026-10-02T11:00:00+09:00'),
    ]);

    await tester.tap(find.byTooltip('다음날'));
    await tester.pumpAndSettle();

    expect(find.text('2026년 10월 2일 (금)'), findsOneWidget);
    expect(find.text('김민지 · 커트'), findsOneWidget);

    await tester.tap(find.byTooltip('전날'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('전날'));
    await tester.pumpAndSettle();

    expect(find.text('2026년 9월 30일 (수)'), findsOneWidget);
    expect(repo.requestedDates, [
      '2026-10-01~2026-10-01',
      '2026-10-02~2026-10-02',
      '2026-10-01~2026-10-01',
      '2026-09-30~2026-09-30',
    ]);
  });

  testWidgets('월말에서 다음날을 누르면 다음 달 1일로 넘어간다', (tester) async {
    await _pump(tester, [], date: DateTime(2026, 10, 31));

    await tester.tap(find.byTooltip('다음날'));
    await tester.pumpAndSettle();

    expect(find.text('2026년 11월 1일 (일)'), findsOneWidget);
  });

  testWidgets('"오늘" 버튼은 서울 기준 오늘로 돌아온다', (tester) async {
    final repo = await _pump(tester, [], date: DateTime(2020, 1, 1));

    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();

    expect(repo.requestedDates.last,
        '${formatIsoDate(kstToday())}~${formatIsoDate(kstToday())}');
    expect(find.text(formatKoreanDate(kstToday())), findsOneWidget);
  });

  testWidgets('취소/노쇼 예약도 목록에 남고 상태가 표시된다', (tester) async {
    await _pump(tester, [
      reservationOf(1, '김민지', '커트', '2026-10-01T10:00:00+09:00', '2026-10-01T11:00:00+09:00',
          status: ReservationStatus.cancelled),
      reservationOf(2, '이하늘', '펌', '2026-10-01T12:00:00+09:00', '2026-10-01T14:00:00+09:00',
          status: ReservationStatus.noShow),
    ]);

    expect(find.text('취소'), findsOneWidget);
    expect(find.text('노쇼'), findsOneWidget);
    expect(find.text('김민지 · 커트'), findsOneWidget);
  });

  testWidgets('서울 자정 직후 예약(UTC로는 전날)은 서울 날짜에 보인다', (tester) async {
    // 서울 10/2 00:30 = UTC 10/1 15:30. UTC 날짜로 거르면 10/1에 잘못 들어간다.
    await _pump(tester, [
      reservationOf(1, '김민지', '커트', '2026-10-01T15:30:00Z', '2026-10-01T16:30:00Z'),
    ], date: DateTime(2026, 10, 2));

    expect(find.text('김민지 · 커트'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('서버 오류는 메시지와 다시 시도 버튼으로 보여주고, 누르면 다시 불러온다', (tester) async {
    final repo = FakeReservationRepository([
      reservationOf(1, '김민지', '커트', '2026-10-01T10:00:00+09:00', '2026-10-01T11:00:00+09:00'),
    ])..failWith = ApiException(500, '서버 오류');
    await tester.pumpWidget(MaterialApp(
      home: SchedulePage(
        repository: repo,
        customerRepository: FakeCustomerRepository([]),
        menuRepository: FakeMenuRepository([]),
        staffRepository: FakeStaffRepository([staffOf(1, '원장', '원장')]),
        saleRepository: FakeSaleRepository(),
        initialDate: DateTime(2026, 10, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('서버 오류'), findsOneWidget);

    repo.failWith = null; // 서버가 복구됨
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('김민지 · 커트'), findsOneWidget);
  });
}
