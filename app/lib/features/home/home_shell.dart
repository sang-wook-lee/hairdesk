import 'package:flutter/material.dart';

import '../menu/menu_list_page.dart';
import '../menu/menu_repository.dart';
import '../reservation/reservation_repository.dart';
import '../reservation/schedule_page.dart';

/// 앱의 뼈대: 아래 탭으로 화면(일정 / 메뉴)을 오간다. 화면이 늘면 탭도 여기에 추가한다.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.reservationRepository,
    required this.menuRepository,
  });

  final ReservationRepository reservationRepository;
  final MenuRepository menuRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: 모든 화면을 만들어 두고 선택된 것만 보여준다.
      // 탭을 옮겼다 돌아와도 보던 날짜나 스크롤 위치가 그대로 남는다.
      body: IndexedStack(
        index: _index,
        children: [
          SchedulePage(repository: widget.reservationRepository),
          MenuListPage(repository: widget.menuRepository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '일정'),
          NavigationDestination(icon: Icon(Icons.content_cut), label: '메뉴'),
        ],
      ),
    );
  }
}
