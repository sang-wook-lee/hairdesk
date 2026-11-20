import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/staff/staff_list_page.dart';

import '../../support/fakes.dart';

Future<void> _pumpList(WidgetTester tester, FakeStaffRepository repository) async {
  await tester.pumpWidget(MaterialApp(home: StaffListPage(repository: repository)));
  await tester.pumpAndSettle();
}

/// 폼의 입력 칸은 위에서부터: 이름, 직책.
Finder get _nameField => find.byType(TextFormField).at(0);
Finder get _positionField => find.byType(TextFormField).at(1);

void main() {
  testWidgets('직원 추가: 이름과 직책을 채워 저장하면 목록에 새 직원이 번호와 함께 나타난다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, '이지수');
    await tester.enterText(_positionField, '실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.created.single.name, '이지수');
    expect(repo.created.single.position, '실장');
    expect(find.text('이지수 (#2)'), findsOneWidget); // 폼이 닫히고 목록이 새로고침됐다
  });

  testWidgets('앞뒤 공백은 잘라서 서버로 보낸다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, '  이지수 ');
    await tester.enterText(_positionField, ' 실장  ');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.created.single.name, '이지수');
    expect(repo.created.single.position, '실장');
  });

  testWidgets('빠른 선택 버튼을 누르면 직책 칸에 그 직책이 채워진다 (직접 고쳐 써도 된다)', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '디자이너'));
    await tester.pump();

    expect(tester.widget<TextFormField>(_positionField).controller!.text, '디자이너');

    await tester.enterText(_positionField, '수석 디자이너'); // 빠른 선택 뒤에도 직접 고칠 수 있다
    await tester.enterText(_nameField, '박민수');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.created.single.position, '수석 디자이너');
  });

  testWidgets('이름과 직책이 이미 있는 직원과 같아도 등록된다 (직원 번호로 구별)', (tester) async {
    final repo = FakeStaffRepository([staffOf(2, '이지수', '실장')]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, '이지수');
    await tester.enterText(_positionField, '실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('이지수 (#2)'), findsOneWidget);
    expect(find.text('이지수 (#3)'), findsOneWidget);
  });

  testWidgets('직원을 누르면 수정 폼에 직원 번호와 기존 값이 채워져 있고, 고쳐 저장하면 반영된다', (tester) async {
    final repo = FakeStaffRepository([
      staffOf(1, '원장', '원장', owner: true),
      staffOf(2, '이지수', '실장'),
    ]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('이지수 (#2)'));
    await tester.pumpAndSettle();

    expect(find.text('직원 수정'), findsOneWidget);
    expect(find.text('직원 번호 #2'), findsOneWidget);
    expect(tester.widget<TextFormField>(_nameField).controller!.text, '이지수');
    expect(tester.widget<TextFormField>(_positionField).controller!.text, '실장');

    await tester.enterText(_positionField, '부원장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.updated.single.$1, 2); // 번호 2번 직원을 수정했다
    expect(repo.updated.single.$2.position, '부원장');
    expect(find.text('부원장'), findsOneWidget);
    expect(repo.created, isEmpty); // 수정은 새 직원을 만들지 않는다
  });

  testWidgets('수정 폼은 주인 여부나 근무 여부를 바꾸는 칸이 없다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('원장 (#1)'));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('이름이나 직책이 비어 있으면 안내하고 서버로 보내지 않는다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력해 주세요'), findsOneWidget);
    expect(find.text('직책을 입력해 주세요'), findsOneWidget);
    expect(repo.created, isEmpty);

    await tester.enterText(_nameField, '   '); // 공백만 입력해도 비어 있는 것으로 본다
    await tester.enterText(_positionField, '실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력해 주세요'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('서버가 거절하면 메시지를 보여주고 폼에 머문다', (tester) async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장', owner: true)])
      ..failOnSave = ApiException(400, '직책은 필수입니다.');
    await _pumpList(tester, repo);

    await tester.tap(find.text('직원 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, '이지수');
    await tester.enterText(_positionField, '실장');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('직책은 필수입니다.'), findsOneWidget); // 서버가 알려 준 이유
    expect(find.text('직원 추가'), findsWidgets); // 폼에 그대로 남아 있다 (제목이 "직원 추가")
    expect(find.text('저장'), findsOneWidget); // 저장 버튼이 다시 눌릴 수 있다
  });
}
