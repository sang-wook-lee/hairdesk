import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/home/home_shell.dart';
import 'package:hairdesk/features/customer/customer_repository.dart';
import 'package:hairdesk/features/menu/menu_repository.dart';
import 'package:hairdesk/features/reservation/reservation_repository.dart';
import 'package:hairdesk/features/sales/sale_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('아래 탭으로 일정과 메뉴 화면을 오간다', (tester) async {
    // 화면 이동만 확인하면 되므로, 모든 요청에 빈 목록을 돌려주는 가짜 HTTP를 쓴다.
    final api = ApiClient(httpClient: MockClient((request) async => http.Response('[]', 200)));
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        reservationRepository: ReservationRepository(api),
        customerRepository: CustomerRepository(api),
        menuRepository: MenuRepository(api),
        saleRepository: SaleRepository(api),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('이 날은 예약이 없어요.'), findsOneWidget); // 첫 화면 = 일정

    await tester.tap(find.text('메뉴').last); // 하단 탭의 "메뉴"
    await tester.pumpAndSettle();

    expect(find.textContaining('등록된 메뉴가 없어요'), findsOneWidget);

    await tester.tap(find.text('일정').last);
    await tester.pumpAndSettle();

    expect(find.text('이 날은 예약이 없어요.'), findsOneWidget);
  });
}
