import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'features/menu/menu_list_page.dart';
import 'features/menu/menu_repository.dart';

/// 앱의 시작점. Dart는 항상 main()부터 실행된다.
/// 여기서 부품(ApiClient, 저장소)을 한 번 만들어 필요한 화면에 넘겨준다. (ADR 0006)
void main() {
  final api = ApiClient();
  runApp(HairdeskApp(menuRepository: MenuRepository(api)));
}

/// 앱 전체의 뼈대. 테마(색, 글꼴)와 첫 화면을 정한다.
class HairdeskApp extends StatelessWidget {
  const HairdeskApp({super.key, required this.menuRepository});

  final MenuRepository menuRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hairdesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: MenuListPage(repository: menuRepository),
    );
  }
}
