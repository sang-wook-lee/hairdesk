import 'package:flutter/material.dart';

import '../customer/customer_repository.dart';
import '../menu/menu_list_page.dart';
import '../menu/menu_repository.dart';
import '../reservation/reservation_repository.dart';
import '../reservation/schedule_page.dart';
import '../sales/sale_repository.dart';
import '../staff/staff_repository.dart';
import '../stats/stats_data.dart';
import '../stats/stats_page.dart';
import 'home_page.dart';

/// 앱의 뼈대: 아래 탭으로 화면(홈 / 일정 / 통계 / 메뉴)을 오간다. 화면이 늘면 탭도 여기에 추가한다.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.reservationRepository,
    required this.customerRepository,
    required this.menuRepository,
    required this.staffRepository,
    required this.saleRepository,
    required this.statsLoader,
    this.clock = DateTime.now,
  });

  final ReservationRepository reservationRepository;
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;
  final StaffRepository staffRepository;
  final SaleRepository saleRepository;
  final StatsLoader statsLoader;

  /// 홈과 통계 화면의 "지금". 테스트에서 시계를 고정할 때 쓴다.
  final DateTime Function() clock;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _homeTab = 0;
  static const _scheduleTab = 1;
  static const _statsTab = 2;
  static const _menuTab = 3;

  int _index = _homeTab;

  /// 홈 탭으로 돌아올 때마다 올린다. 홈 화면의 key로 쓰면 "새 화면"으로 취급되어 데이터를 다시 불러온다.
  /// (일정 탭에서 결제하고 홈으로 돌아왔을 때 매출 숫자가 옛날 값으로 남지 않게 하려는 장치)
  int _homeVersion = 0;

  /// 통계 탭은 처음 눌렀을 때 비로소 만든다. (앱을 켤 때마다 통계용 서버 호출 6개를 보내지 않으려고)
  bool _statsOpened = false;

  /// 통계 탭에 "다시 불러와"를 알리는 신호. 값이 바뀔 때마다 통계 화면이 보던 달 그대로 새로 불러온다.
  /// 홈처럼 화면을 통째로 새로 만들면 보던 달이 이번 달로 돌아가 버려서, 신호만 보내는 방식을 쓴다.
  final ValueNotifier<int> _statsRefresh = ValueNotifier(0);

  @override
  void dispose() {
    _statsRefresh.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      if (index == _homeTab && _index != _homeTab) _homeVersion++;
      if (index == _statsTab) {
        // 이미 열어 본 적이 있으면 다시 들어올 때 새로고침한다. 처음이면 화면이 만들어지면서 알아서 불러온다.
        if (_statsOpened && _index != _statsTab) _statsRefresh.value++;
        _statsOpened = true;
      }
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
            staffRepository: widget.staffRepository,
            saleRepository: widget.saleRepository,
            onOpenSchedule: () => _select(_scheduleTab),
            onOpenStats: () => _select(_statsTab),
            onOpenMenus: () => _select(_menuTab),
            clock: widget.clock,
          ),
          SchedulePage(
            repository: widget.reservationRepository,
            customerRepository: widget.customerRepository,
            menuRepository: widget.menuRepository,
            staffRepository: widget.staffRepository,
            saleRepository: widget.saleRepository,
          ),
          _statsOpened
              ? StatsPage(loader: widget.statsLoader, refresh: _statsRefresh, clock: widget.clock)
              : const SizedBox.shrink(), // 아직 한 번도 안 열었다
          MenuListPage(repository: widget.menuRepository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '일정'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '통계'),
          NavigationDestination(icon: Icon(Icons.content_cut), label: '메뉴'),
        ],
      ),
    );
  }
}
