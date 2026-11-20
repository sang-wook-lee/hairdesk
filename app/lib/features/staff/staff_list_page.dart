import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/error_view.dart';
import 'staff.dart';
import 'staff_repository.dart';

/// 직원 목록 화면. 메뉴 목록 화면과 같은 모양이다. (근무 종료 직원은 스위치를 켜야 보인다)
///
/// 이 화면은 지금 "보여주기"만 한다. 등록·수정, 근무 종료·재개, 주인 지정은 다음 조각에서 붙인다.
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
            itemBuilder: (context, index) => StaffTile(staff: staff[index]),
          );
        },
      ),
    );
  }
}

/// 직원 한 줄. 이름은 번호와 함께 보여준다 (동명이인 구별).
/// 주인에게는 "주인" 표시를, 근무를 마친 직원은 회색과 "근무 종료"를 붙인다.
class StaffTile extends StatelessWidget {
  const StaffTile({super.key, required this.staff});

  final Staff staff;

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
    );
  }
}
