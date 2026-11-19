import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/error_view.dart';

void main() {
  testWidgets('메시지를 보여주고, 다시 시도를 누르면 onRetry가 호출된다', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorView(message: '서버에 연결할 수 없어요', onRetry: () => retried++),
      ),
    ));

    expect(find.text('서버에 연결할 수 없어요'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });
}
