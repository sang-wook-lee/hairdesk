import 'package:flutter/material.dart';

import 'features/connection_check_page.dart';

/// 앱의 시작점. Dart는 항상 main()부터 실행된다.
void main() {
  runApp(const HairdeskApp());
}

/// 앱 전체의 뼈대. 테마(색, 글꼴)와 첫 화면을 정한다.
class HairdeskApp extends StatelessWidget {
  const HairdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hairdesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ConnectionCheckPage(),
    );
  }
}
