import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/staff/staff_list_page.dart';

import '../../support/fakes.dart';

Future<void> _pumpList(WidgetTester tester, FakeStaffRepository repository) async {
  await tester.pumpWidget(MaterialApp(home: StaffListPage(repository: repository)));
  await tester.pumpAndSettle();
}

/// 직원 줄의 ⋮ 메뉴를 연다. [tile]은 "이지수 (#2)" 같은 줄의 제목이다.
Future<void> _openMenu(WidgetTester tester, String tile) async {
  final row = find.ancestor(of: find.text(tile), matching: find.byType(ListTile));
  await tester.tap(find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('근무 중인 직원의 메뉴에는 수정과 근무 종료가 있고, 근무 재개는 없다', (tester) async {
    final repo = FakeStaffRepository([staffOf(2, '이지수', '실장')]);
    await _pumpList(tester, repo);

    await _openMenu(tester, '이지수 (#2)');

    expect(find.text('수정'), findsOneWidget);
    expect(find.text('근무 종료'), findsOneWidget);
    expect(find.text('근무 재개'), findsNothing);
  });

  testWidgets('근무를 마친 직원의 메뉴에는 수정과 근무 재개가 있고, 근무 종료는 없다', (tester) async {
    final repo = FakeStaffRepository([staffOf(4, '서하윤', '인턴', active: false)]);
    await _pumpList(tester, repo);
    await tester.tap(find.byType(Switch)); // 근무 종료 직원도 보이게
    await tester.pumpAndSettle();

    await _openMenu(tester, '서하윤 (#4)');

    expect(find.text('수정'), findsOneWidget);
    expect(find.text('근무 재개'), findsOneWidget);
    expect(find.text('근무 종료'), findsNothing);
  });

  testWidgets('근무 종료: 확인 창에서 "취소"를 누르면 서버로 보내지 않고 직원도 그대로다', (tester) async {
    final repo = FakeStaffRepository([staffOf(2, '이지수', '실장')]);
    await _pumpList(tester, repo);

    await _openMenu(tester, '이지수 (#2)');
    await tester.tap(find.text('근무 종료'));
    await tester.pumpAndSettle();

    expect(find.text('근무를 종료할까요?'), findsOneWidget);
    expect(find.textContaining('이미 잡힌 앞으로의 예약은 그대로 남아요'), findsOneWidget); // 알려진 한계를 사용자에게 알린다

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repo.toggled, isEmpty);
    expect(find.text('이지수 (#2)'), findsOneWidget);
  });

  testWidgets('근무 종료: 확인 창에서 "근무 종료"를 누르면 요청이 가고, 목록에서 사라지고 알림이 뜬다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')]);
    await _pumpList(tester, repo);

    await _openMenu(tester, '이지수 (#2)');
    await tester.tap(find.text('근무 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '근무 종료'));
    await tester.pumpAndSettle();

    expect(repo.toggled, [(2, false)]); // 2번 직원을 근무 종료로
    expect(find.text('이지수 (#2)'), findsNothing); // 기본 목록은 근무 중인 직원만
    expect(find.text('원장 (#1)'), findsOneWidget);
    expect(find.text('이지수 (#2)의 근무를 종료했어요'), findsOneWidget); // SnackBar

    await tester.tap(find.byType(Switch)); // 근무 종료 포함
    await tester.pumpAndSettle();
    expect(find.text('실장 · 근무 종료'), findsOneWidget);
  });

  testWidgets('근무 재개는 확인 없이 바로 처리되고, 목록에 다시 나타난다', (tester) async {
    final repo = FakeStaffRepository([staffOf(4, '서하윤', '인턴', active: false)]);
    await _pumpList(tester, repo);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await _openMenu(tester, '서하윤 (#4)');
    await tester.tap(find.text('근무 재개'));
    await tester.pumpAndSettle();

    expect(find.text('근무를 종료할까요?'), findsNothing); // 확인 창 없음
    expect(repo.toggled, [(4, true)]);
    expect(find.text('서하윤 (#4)의 근무를 재개했어요'), findsOneWidget);
    expect(find.text('인턴'), findsOneWidget); // 더 이상 "근무 종료"가 붙지 않는다
  });

  testWidgets('마지막 근무 직원도 근무 종료할 수 있다 (예외 없음, ADR 0011)', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장')]);
    await _pumpList(tester, repo);

    await _openMenu(tester, '원장 (#1)');
    await tester.tap(find.text('근무 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '근무 종료'));
    await tester.pumpAndSettle();

    expect(repo.toggled, [(1, false)]);
    expect(find.textContaining('근무 중인 직원이 없어요'), findsOneWidget);
  });

  testWidgets('서버가 거절하면 그 이유를 알리고 목록은 그대로다', (tester) async {
    final repo = FakeStaffRepository([staffOf(2, '이지수', '실장')])
      ..failOnToggle = ApiException(404, '직원을 찾을 수 없습니다. 직원 번호=2');
    await _pumpList(tester, repo);

    await _openMenu(tester, '이지수 (#2)');
    await tester.tap(find.text('근무 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '근무 종료'));
    await tester.pumpAndSettle();

    expect(find.text('직원을 찾을 수 없습니다. 직원 번호=2'), findsOneWidget);
    expect(find.text('이지수 (#2)'), findsOneWidget);
  });

  testWidgets('메뉴의 "수정"을 누르면 수정 폼이 열린다', (tester) async {
    final repo = FakeStaffRepository([staffOf(2, '이지수', '실장')]);
    await _pumpList(tester, repo);

    await _openMenu(tester, '이지수 (#2)');
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    expect(find.text('직원 수정'), findsOneWidget);
    expect(find.text('직원 번호 #2'), findsOneWidget);
  });
}
