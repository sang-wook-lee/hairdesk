import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/error_view.dart';
import 'staff.dart';
import 'staff_form_page.dart';
import 'staff_repository.dart';

/// 직원 목록 화면. 메뉴 목록 화면과 같은 모양이다. (근무 종료 직원은 스위치를 켜야 보인다)
///
/// 보기, 등록·수정, 근무 종료·재개를 한다. 근무 종료는 실수로 누르기 쉬워서 확인 창을 거치고, 재개는 바로 처리한다.
class StaffListPage extends StatefulWidget {
  const StaffListPage({super.key, required this.repository, this.appBarBottom});

  final StaffRepository repository;

  /// 앱바 아래에 붙일 위젯. "시술 메뉴 | 직원" 전환 버튼이 들어온다. (ManagePage)
  final PreferredSizeWidget? appBarBottom;

  @override
  State<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  late Future<List<Staff>> _staff;
  bool _includeInactive = false;

  @override
  void initState() {
    super.initState();
    _staff = _load();
  }

  Future<List<Staff>> _load() => widget.repository.fetchAll(includeInactive: _includeInactive);

  void _reload() {
    setState(() {
      _staff = _load();
    });
  }

  /// 폼 화면을 열고, 저장하고 돌아왔으면(true) 목록을 새로고침한다. [staff]가 null이면 새 직원 등록.
  Future<void> _openForm({Staff? staff}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffFormPage(repository: widget.repository, staff: staff),
      ),
    );
    if (saved == true) _reload();
  }

  /// 근무 종료/재개. 종료는 확인 창에서 "근무 종료"를 눌러야 서버로 간다.
  /// (모든 직원이 같은 규칙이다. 마지막 근무 직원도 종료할 수 있고, 재개로 되돌린다. ADR 0011)
  Future<void> _toggleActive(Staff staff) async {
    final activate = !staff.active;
    if (!activate) {
      final confirmed = await _confirmDeactivate(staff);
      if (confirmed != true) return;
    }
    try {
      await widget.repository.setActive(staff.id, active: activate);
      _reload();
      if (!mounted) return;
      _toast(activate ? '${staff.displayName}의 근무를 재개했어요' : '${staff.displayName}의 근무를 종료했어요');
    } catch (e) {
      // await 뒤에는 화면이 이미 닫혔을 수 있다. 닫힌 화면에 SnackBar를 띄우면 에러라서 확인한다.
      if (!mounted) return;
      _toast(errorMessage(e));
    }
  }

  Future<bool?> _confirmDeactivate(Staff staff) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('근무를 종료할까요?'),
        content: Text(
          '${staff.displayName}에게는 새 예약을 받을 수 없게 돼요.\n'
          '이미 잡힌 앞으로의 예약은 그대로 남아요.\n'
          '언제든 다시 재개할 수 있어요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('근무 종료')),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('직원'),
        bottom: widget.appBarBottom,
        actions: [
          const Text('근무 종료 포함'),
          Switch(
            value: _includeInactive,
            onChanged: (value) {
              _includeInactive = value;
              _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Staff>>(
        future: _staff,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: errorMessage(snapshot.error!), onRetry: _reload);
          }
          final staff = snapshot.data!;
          if (staff.isEmpty) {
            return const Center(
              child: Text('근무 중인 직원이 없어요.', textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            itemCount: staff.length,
            itemBuilder: (context, index) => StaffTile(
              staff: staff[index],
              onTap: () => _openForm(staff: staff[index]),
              onToggleActive: () => _toggleActive(staff[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('직원 추가'),
      ),
    );
  }
}

/// 직원 한 줄. 이름은 번호와 함께 보여준다 (동명이인 구별).
/// 근무를 마친 직원은 회색과 "근무 종료"를 붙인다. 오른쪽 ⋮ 메뉴에서 수정과 근무 종료/재개를 한다.
class StaffTile extends StatelessWidget {
  const StaffTile({
    super.key,
    required this.staff,
    required this.onTap,
    required this.onToggleActive,
  });

  final Staff staff;
  final VoidCallback onTap; // 누르면 수정 폼을 연다
  final VoidCallback onToggleActive; // 근무 종료(근무 중일 때) / 재개(근무 종료일 때)

  @override
  Widget build(BuildContext context) {
    final textColor = staff.active ? null : Theme.of(context).disabledColor;
    return ListTile(
      title: Text(staff.displayName, style: TextStyle(color: textColor)),
      subtitle: Text(
        '${staff.position}${staff.active ? '' : ' · 근무 종료'}',
        style: TextStyle(color: textColor),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onTap();
          if (value == 'toggle') onToggleActive();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'toggle', child: Text(staff.active ? '근무 종료' : '근무 재개')),
        ],
      ),
      onTap: onTap,
    );
  }
}
