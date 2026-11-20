import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/core/error_view.dart';
import 'package:hairdesk/features/staff/staff_list_page.dart';

import '../../support/fakes.dart';

Future<void> _pumpList(WidgetTester tester, FakeStaffRepository repository) async {
  await tester.pumpWidget(MaterialApp(home: StaffListPage(repository: repository)));
  await tester.pumpAndSettle(); // 서버 응답(Future)과 애니메이션이 끝날 때까지 기다린다
}

void main() {
  testWidgets('직원은 이름과 번호, 직책으로 보이고, "주인" 같은 특별한 표시는 없다', (tester) async {
    final repo = FakeStaffRepository([
      staffOf(1, '원장', '원장'),
      staffOf(2, '이지수', '실장'),
    ]);

    await _pumpList(tester, repo);

    expect(find.text('원장 (#1)'), findsOneWidget);
    expect(find.text('이지수 (#2)'), findsOneWidget);
    expect(find.text('실장'), findsOneWidget);
    expect(find.text('주인'), findsNothing); // 모든 직원이 같은 규칙이다 (ADR 0011)
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('이름과 직책이 같은 직원도 번호로 구별되어 둘 다 보인다', (tester) async {
    final repo = FakeStaffRepository([
      staffOf(2, '이지수', '실장'),
      staffOf(5, '이지수', '실장'),
    ]);

    await _pumpList(tester, repo);

    expect(find.text('이지수 (#2)'), findsOneWidget);
    expect(find.text('이지수 (#5)'), findsOneWidget);
  });

  testWidgets('근무 종료 직원은 기본으로 숨기고, 스위치를 켜면 "근무 종료"로 보여준다', (tester) async {
    final repo = FakeStaffRepository([
      staffOf(1, '원장', '원장'),
      staffOf(4, '서하윤', '인턴', active: false),
    ]);

    await _pumpList(tester, repo);
    expect(find.text('서하윤 (#4)'), findsNothing);
    expect(repo.fetchedWithInactive, [false]); // 처음에는 근무 중인 직원만 요청했다

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('서하윤 (#4)'), findsOneWidget);
    expect(find.text('인턴 · 근무 종료'), findsOneWidget);
    expect(repo.fetchedWithInactive, [false, true]);
  });

  testWidgets('근무 종료 직원의 글자는 회색이다', (tester) async {
    final repo = FakeStaffRepository([staffOf(4, '서하윤', '인턴', active: false)]);
    await _pumpList(tester, repo);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('서하윤 (#4)'));
    expect(title.style?.color, isNotNull);
  });

  testWidgets('직원이 없으면 안내 문구를 보여준다', (tester) async {
    await _pumpList(tester, FakeStaffRepository([]));

    expect(find.textContaining('근무 중인 직원이 없어요'), findsOneWidget);
  });

  testWidgets('서버가 실패하면 오류 화면과 "다시 시도"가 나오고, 복구되면 다시 불러온다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장')])
      ..failOnFetch = ApiException(500, '서버 오류');

    await _pumpList(tester, repo);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('서버 오류'), findsOneWidget);

    repo.failOnFetch = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('원장 (#1)'), findsOneWidget);
  });
}
