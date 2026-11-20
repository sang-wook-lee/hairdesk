import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/error_view.dart';
import 'staff.dart';
import 'staff_form_page.dart';
import 'staff_repository.dart';

/// 직원 목록 화면. 메뉴 목록 화면과 같은 모양이다. (근무 종료 직원은 스위치를 켜야 보인다)
///
/// 지금은 보기와 등록·수정을 한다. 근무 종료·재개, 주인 지정은 다음 조각에서 붙인다.
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
/// 주인에게는 "주인" 표시를, 근무를 마친 직원은 회색과 "근무 종료"를 붙인다.
class StaffTile extends StatelessWidget {
  const StaffTile({super.key, required this.staff, required this.onTap});

  final Staff staff;
  final VoidCallback onTap; // 누르면 수정 폼을 연다

  @override
  Widget build(BuildContext context) {
    final textColor = staff.active ? null : Theme.of(context).disabledColor;
    return ListTile(
      title: Text(staff.displayName, style: TextStyle(color: textColor)),
      subtitle: Text(
        '${staff.position}${staff.active ? '' : ' · 근무 종료'}',
        style: TextStyle(color: textColor),
      ),
      trailing: staff.owner
          ? const Chip(
              label: Text('주인'),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            )
          : null,
      onTap: onTap,
    );
  }
}
