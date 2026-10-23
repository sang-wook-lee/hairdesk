import 'package:flutter/material.dart';

import '../customer/customer_repository.dart';
import '../menu/menu_list_page.dart';
import '../menu/menu_repository.dart';
import '../reservation/reservation_repository.dart';
import '../reservation/schedule_page.dart';
import '../sales/sale_repository.dart';
import 'home_page.dart';

/// 앱의 뼈대: 아래 탭으로 화면(홈 / 일정 / 메뉴)을 오간다. 화면이 늘면 탭도 여기에 추가한다.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.reservationRepository,
    required this.customerRepository,
    required this.menuRepository,
    required this.saleRepository,
    this.clock = DateTime.now,
  });

  final ReservationRepository reservationRepository;
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;
  final SaleRepository saleRepository;

  /// 홈 화면의 "지금". 테스트에서 시계를 고정할 때 쓴다.
  final DateTime Function() clock;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _homeTab = 0;
  static const _scheduleTab = 1;
  static const _menuTab = 2;

  int _index = _homeTab;

  /// 홈 탭으로 돌아올 때마다 올린다. 홈 화면의 key로 쓰면 "새 화면"으로 취급되어 데이터를 다시 불러온다.
  /// (일정 탭에서 결제하고 홈으로 돌아왔을 때 매출 숫자가 옛날 값으로 남지 않게 하려는 장치)
  int _homeVersion = 0;

  void _select(int index) {
    setState(() {
      if (index == _homeTab && _index != _homeTab) _homeVersion++;
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: 모든 화면을 만들어 두고 선택된 것만 보여준다.
      // 탭을 옮겼다 돌아와도 일정에서 보던 날짜나 스크롤 위치가 그대로 남는다.
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            key: ValueKey(_homeVersion),
            reservationRepository: widget.reservationRepository,
            customerRepository: widget.customerRepository,
            menuRepository: widget.menuRepository,
            saleRepository: widget.saleRepository,
            onOpenSchedule: () => _select(_scheduleTab),
            onOpenMenus: () => _select(_menuTab),
            clock: widget.clock,
          ),
          SchedulePage(
            repository: widget.reservationRepository,
            customerRepository: widget.customerRepository,
            menuRepository: widget.menuRepository,
            saleRepository: widget.saleRepository,
          ),
          MenuListPage(repository: widget.menuRepository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '일정'),
          NavigationDestination(icon: Icon(Icons.content_cut), label: '메뉴'),
        ],
      ),
    );
  }
}
