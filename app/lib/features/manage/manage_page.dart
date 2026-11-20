import 'package:flutter/material.dart';

import '../menu/menu_list_page.dart';
import '../menu/menu_repository.dart';
import '../staff/staff_list_page.dart';
import '../staff/staff_repository.dart';

/// 하단 "메뉴" 탭의 화면. 위쪽 전환 버튼으로 "시술 메뉴"와 "직원" 두 목록을 오간다.
///
/// 두 화면은 각자 앱바와 목록을 가지고 있고, 이 화면은 전환 버튼만 얹어 준다.
/// IndexedStack으로 둘 다 만들어 두므로, 전환했다가 돌아와도 스위치 상태와 목록이 그대로 남는다.
class ManagePage extends StatefulWidget {
  const ManagePage({super.key, required this.menuRepository, required this.staffRepository});

  final MenuRepository menuRepository;
  final StaffRepository staffRepository;

  @override
  State<ManagePage> createState() => _ManagePageState();
}

enum _Section { menu, staff }

class _ManagePageState extends State<ManagePage> {
  _Section _section = _Section.menu;

  /// 두 화면의 앱바 아래에 똑같이 붙는 전환 버튼.
  PreferredSizeWidget get _switcher => PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<_Section>(
            segments: const [
              ButtonSegment(value: _Section.menu, label: Text('시술 메뉴')),
              ButtonSegment(value: _Section.staff, label: Text('직원')),
            ],
            selected: {_section},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() => _section = selection.first),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _section.index,
      children: [
        MenuListPage(repository: widget.menuRepository, appBarBottom: _switcher),
        StaffListPage(repository: widget.staffRepository, appBarBottom: _switcher),
      ],
    );
  }
}
