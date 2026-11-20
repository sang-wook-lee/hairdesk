import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/reservation/reservation_tile.dart';

import '../../support/fakes.dart';

Future<void> _pump(WidgetTester tester, {required bool showStaff, String? memo}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ReservationTile(
        reservation: reservationOf(
          1, '김민지', '커트', '2026-10-01T14:00:00+09:00', '2026-10-01T15:00:00+09:00',
          memo: memo, staffId: 2, staffName: '이지수', staffPosition: '실장',
        ),
        onTap: () {},
        showStaff: showStaff,
      ),
    ),
  ));
}

void main() {
  testWidgets('showStaff가 켜져 있으면 줄 아래에 "담당 이름 (#번호)"가 나온다', (tester) async {
    await _pump(tester, showStaff: true);

    expect(find.text('담당 이지수 (#2)'), findsOneWidget);
  });

  testWidgets('showStaff가 꺼져 있으면 담당자는 나오지 않는다', (tester) async {
    await _pump(tester, showStaff: false);

    expect(find.textContaining('담당'), findsNothing);
  });

  testWidgets('담당자와 메모가 함께 있으면 두 줄 모두 보인다', (tester) async {
    await _pump(tester, showStaff: true, memo: '두피 민감');

    expect(find.text('담당 이지수 (#2)'), findsOneWidget);
    expect(find.text('두피 민감'), findsOneWidget);
  });

  testWidgets('담당자 표시가 꺼져 있고 메모도 없으면 보조 글자 자리가 비어 있다', (tester) async {
    await _pump(tester, showStaff: false);

    expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
  });
}
