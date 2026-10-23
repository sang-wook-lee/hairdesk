import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'features/customer/customer_repository.dart';
import 'features/home/home_shell.dart';
import 'features/menu/menu_repository.dart';
import 'features/reservation/reservation_repository.dart';

/// 앱의 시작점. Dart는 항상 main()부터 실행된다.
/// 여기서 부품(ApiClient, 저장소)을 한 번 만들어 필요한 화면에 넘겨준다. (ADR 0006)
void main() {
  final api = ApiClient();
  runApp(HairdeskApp(
    menuRepository: MenuRepository(api),
    customerRepository: CustomerRepository(api),
    reservationRepository: ReservationRepository(api),
  ));
}

/// 앱 전체의 뼈대. 테마(색, 글꼴)와 첫 화면을 정한다.
class HairdeskApp extends StatelessWidget {
  const HairdeskApp({
    super.key,
    required this.menuRepository,
    required this.customerRepository,
    required this.reservationRepository,
  });

  final MenuRepository menuRepository;
  final CustomerRepository customerRepository;
  final ReservationRepository reservationRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hairdesk',
      debugShowCheckedModeBanner: false,
      // 달력, 시간 선택 같은 기본 위젯의 글자를 한글로 보여준다.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeShell(
        reservationRepository: reservationRepository,
        customerRepository: customerRepository,
        menuRepository: menuRepository,
      ),
    );
  }
}
