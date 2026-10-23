import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/customer/customer.dart';
import 'package:hairdesk/features/customer/customer_picker_page.dart';

import '../../support/fakes.dart';

/// 고객 선택 화면은 "열고 → 결과를 받는" 화면이라, 그 결과를 담아 두는 작은 시작 화면에 올려서 테스트한다.
class _Opener {
  Customer? result;

  Future<void> pump(WidgetTester tester, FakeCustomerRepository repo) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Customer>(
                MaterialPageRoute(builder: (_) => CustomerPickerPage(repository: repo)),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }
}

FakeCustomerRepository _repo() => FakeCustomerRepository([
      customerOf(1, '김민지', '01012345678', memo: '두피 민감'),
      customerOf(2, '이하늘', '01099990000'),
    ]);

void main() {
  testWidgets('처음에는 전체 고객을 이름, 번호(하이픈), 메모와 함께 보여준다', (tester) async {
    await _Opener().pump(tester, _repo());

    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('010-1234-5678 · 두피 민감'), findsOneWidget);
    expect(find.text('이하늘'), findsOneWidget);
    expect(find.text('010-9999-0000'), findsOneWidget);
  });

  testWidgets('번호 뒷자리로 검색하면 입력이 멈춘 뒤에 한 번만 서버에 묻는다 (디바운스)', (tester) async {
    final repo = _repo();
    await _Opener().pump(tester, repo);

    // 한 글자씩 빠르게 입력: 매번 서버를 부르면 안 된다
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '56');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '5678');
    await tester.pump(const Duration(milliseconds: 400)); // 입력이 멈춘 뒤
    await tester.pumpAndSettle();

    expect(repo.searches, ['', '5678']); // 처음 전체 조회 + 최종 검색어 한 번
    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('이하늘'), findsNothing);
  });

  testWidgets('검색 결과가 없으면 안내한다', (tester) async {
    await _Opener().pump(tester, _repo());

    await tester.enterText(find.byType(TextField), '없는사람');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('찾는 고객이 없어요.'), findsOneWidget);
  });

  testWidgets('고객을 탭하면 그 고객을 결과로 돌려주며 닫힌다', (tester) async {
    final opener = _Opener();
    await opener.pump(tester, _repo());

    await tester.tap(find.text('이하늘'));
    await tester.pumpAndSettle();

    expect(opener.result?.id, 2);
    expect(find.text('고객 선택'), findsNothing); // 화면이 닫혔다
  });

  testWidgets('새 고객을 등록하면 바로 선택된 것으로 돌려준다', (tester) async {
    final repo = _repo();
    final opener = _Opener();
    await opener.pump(tester, repo);

    await tester.tap(find.text('새 고객 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '이름'), '박서준');
    await tester.enterText(find.widgetWithText(TextFormField, '휴대폰 번호'), '010-5555-6666');
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(repo.created.single.name, '박서준');
    expect(repo.created.single.phone, '010-5555-6666'); // 하이픈 정리는 서버 몫이라 입력 그대로 보낸다
    expect(opener.result?.name, '박서준');
    expect(opener.result?.phone, '01055556666');
  });

  testWidgets('새 고객 폼: 이름이 비었거나 번호가 휴대폰 형식이 아니면 안내하고 보내지 않는다', (tester) async {
    final repo = _repo();
    await _Opener().pump(tester, repo);

    await tester.tap(find.text('새 고객 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '휴대폰 번호'), '02-123-4567'); // 유선 번호
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 입력해 주세요'), findsOneWidget);
    expect(find.text('올바른 휴대폰 번호를 입력해 주세요'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('이미 등록된 고객이라 서버가 거절하면 대화상자 안에 이유를 보여준다', (tester) async {
    final repo = _repo()..failOnCreate = ApiException(409, '이미 등록된 고객입니다: 김민지');
    await _Opener().pump(tester, repo);

    await tester.tap(find.text('새 고객 등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '이름'), '김민지');
    await tester.enterText(find.widgetWithText(TextFormField, '휴대폰 번호'), '01012345678');
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(find.text('이미 등록된 고객입니다: 김민지'), findsOneWidget);
    expect(find.text('새 고객 등록'), findsWidgets); // 대화상자가 그대로 열려 있다
  });
}
