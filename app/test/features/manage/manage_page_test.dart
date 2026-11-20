import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/manage/manage_page.dart';

import '../../support/fakes.dart';

Future<void> _pump(WidgetTester tester, FakeMenuRepository menus, FakeStaffRepository staff) async {
  await tester.pumpWidget(MaterialApp(
    home: ManagePage(menuRepository: menus, staffRepository: staff),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음에는 시술 메뉴가 보이고, "직원"을 누르면 직원 목록으로 바뀐다', (tester) async {
    final staff = FakeStaffRepository([staffOf(1, '원장', '원장')]);
    await _pump(tester, FakeMenuRepository([menuOf(1, '커트')]), staff);

    expect(find.text('커트 · 1시간'), findsOneWidget);
    expect(find.text('원장 (#1)'), findsNothing);
    // 직원 화면은 미리 만들어 두지만 아직 보이지는 않는다 (IndexedStack은 안 보이는 화면을 숨긴다)
    expect(find.text('원장 (#1)', skipOffstage: false), findsOneWidget);

    // SegmentedButton의 칸은 글자를 눌러서 바꾼다
    await tester.tap(find.text('직원').last);
    await tester.pumpAndSettle();

    expect(find.text('원장 (#1)'), findsOneWidget);
    expect(find.text('커트 · 1시간'), findsNothing);
  });

  testWidgets('전환 버튼은 화면 폭을 꽉 채운다 (글자 폭 계산에 기대지 않는다)', (tester) async {
    // 실제 폰 브라우저에서 버튼이 글자 폭만큼만 좁게 그려져 "시술 메뉴"가 두 줄로 잘린 적이 있다.
    // 테스트의 글꼴은 브라우저의 한글 글꼴과 폭이 달라 글자 수로는 재현되지 않으므로,
    // 버튼이 주어진 폭을 꽉 채워 각 칸이 충분히 넓은지를 직접 확인한다.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, FakeMenuRepository([menuOf(1, '커트')]),
        FakeStaffRepository([staffOf(1, '원장', '원장')]));

    final switcher = find.byWidgetPredicate((w) => w is SegmentedButton);
    // 화면 폭 375에서 좌우 여백 16씩을 뺀 343이다.
    expect(tester.getSize(switcher.first).width, 343);
  });

  testWidgets('다시 "시술 메뉴"를 누르면 메뉴 목록으로 돌아온다', (tester) async {
    await _pump(tester, FakeMenuRepository([menuOf(1, '커트')]),
        FakeStaffRepository([staffOf(1, '원장', '원장')]));

    await tester.tap(find.text('직원').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('시술 메뉴').last);
    await tester.pumpAndSettle();

    expect(find.text('커트 · 1시간'), findsOneWidget);
    expect(find.text('원장 (#1)'), findsNothing);
  });

  testWidgets('전환했다 돌아와도 직원 화면의 "근무 종료 포함" 스위치가 그대로 남는다', (tester) async {
    final staff = FakeStaffRepository([
      staffOf(1, '원장', '원장'),
      staffOf(4, '서하윤', '인턴', active: false),
    ]);
    await _pump(tester, FakeMenuRepository([menuOf(1, '커트')]), staff);

    await tester.tap(find.text('직원').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch)); // 직원 화면의 스위치를 켠다
    await tester.pumpAndSettle();
    expect(find.text('서하윤 (#4)'), findsOneWidget);

    await tester.tap(find.text('시술 메뉴').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('직원').last);
    await tester.pumpAndSettle();

    expect(find.text('서하윤 (#4)'), findsOneWidget); // 켜 둔 상태가 유지된다
  });
}
