import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/error_view.dart';
import '../../core/format.dart';
import 'menu.dart';
import 'menu_form_page.dart';
import 'menu_repository.dart';

/// 시술 메뉴 목록 화면. 메뉴 추가, 수정, 판매 중지/재개를 할 수 있다.
class MenuListPage extends StatefulWidget {
  const MenuListPage({super.key, required this.repository});

  /// 서버와 통신하는 저장소. 생성자로 받아서, 테스트에서는 가짜를 넣을 수 있다.
  final MenuRepository repository;

  @override
  State<MenuListPage> createState() => _MenuListPageState();
}

class _MenuListPageState extends State<MenuListPage> {
  late Future<List<Menu>> _menus;
  bool _includeInactive = false;

  @override
  void initState() {
    super.initState();
    _menus = _load();
  }

  Future<List<Menu>> _load() =>
      widget.repository.fetchAll(includeInactive: _includeInactive);

  /// 목록을 서버에서 다시 불러와 화면을 갱신한다.
  void _reload() {
    setState(() {
      _menus = _load();
    });
  }

  /// 폼 화면을 열고, 저장하고 돌아왔으면(true) 목록을 새로고침한다.
  /// Navigator.push는 "그 화면이 pop(결과)로 닫힐 때 그 결과"를 돌려준다.
  Future<void> _openForm({Menu? menu, required int suggestedOrder}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MenuFormPage(
          repository: widget.repository,
          menu: menu,
          suggestedOrder: suggestedOrder,
        ),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleActive(Menu menu) async {
    try {
      await widget.repository.setActive(menu.id, active: !menu.active);
      _reload();
    } catch (e) {
      // await 뒤에는 화면이 이미 닫혔을 수 있다. 닫힌 화면에 SnackBar를 띄우면 에러라서 확인한다.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시술 메뉴'),
        actions: [
          const Text('판매 중지 포함'),
          Switch(
            value: _includeInactive,
            onChanged: (value) {
              _includeInactive = value;
              _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Menu>>(
        future: _menus,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: errorMessage(snapshot.error!),
              onRetry: _reload,
            );
          }
          final menus = snapshot.data!;
          if (menus.isEmpty) {
            return const Center(
              child: Text(
                '등록된 메뉴가 없어요.\n아래 버튼으로 첫 메뉴를 추가해 보세요.',
                textAlign: TextAlign.center,
              ),
            );
          }
          // ListView.builder: 화면에 보이는 줄만 만들어서 긴 목록도 가볍다.
          return ListView.builder(
            itemCount: menus.length,
            itemBuilder: (context, index) => _MenuTile(
              menu: menus[index],
              onEdit: () => _openForm(
                menu: menus[index],
                suggestedOrder: menus[index].displayOrder,
              ),
              onToggleActive: () => _toggleActive(menus[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // 새 메뉴의 표시 순서 기본값 = 지금 목록의 마지막 순서 + 1.
          // 목록을 못 불러온 상태(서버 오류)에서도 추가 버튼이 죽지 않게 실패하면 빈 목록으로 본다.
          List<Menu> menus;
          try {
            menus = await _menus;
          } catch (_) {
            menus = [];
          }
          final last = menus.isEmpty
              ? 0
              : menus.map((m) => m.displayOrder).reduce((a, b) => a > b ? a : b);
          await _openForm(suggestedOrder: last + 1);
        },
        icon: const Icon(Icons.add),
        label: const Text('메뉴 추가'),
      ),
    );
  }
}

/// 메뉴 한 줄. 판매 중지된 메뉴는 회색으로 보여주고 "판매 중지" 표시를 붙인다.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.menu,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Menu menu;
  final VoidCallback onEdit; // VoidCallback = 인자도 반환도 없는 함수 () => void
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final textColor = menu.active ? null : Theme.of(context).disabledColor;
    return ListTile(
      title: Text(menu.name, style: TextStyle(color: textColor)),
      subtitle: Text(
        '${menu.category.label} · ${formatDuration(menu.durationMinutes)}'
        '${menu.active ? '' : ' · 판매 중지'}',
        style: TextStyle(color: textColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatWon(menu.price), style: TextStyle(color: textColor)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'toggle') onToggleActive();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(menu.active ? '판매 중지' : '판매 재개'),
              ),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}
