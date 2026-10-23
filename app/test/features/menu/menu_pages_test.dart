import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/menu/menu.dart';
import 'package:hairdesk/features/menu/menu_list_page.dart';
import 'package:hairdesk/features/menu/menu_repository.dart';

/// 서버 대신 메모리에 메뉴를 들고 있는 가짜 저장소.
/// MenuRepository를 implements하면 같은 모양의 메서드를 직접 채워야 해서, 화면이 쓰는 기능이 한눈에 보인다.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository(this.menus);

  final List<Menu> menus;
  final List<MenuInput> created = [];
  ApiException? failOnCreate;

  @override
  Future<List<Menu>> fetchAll({bool includeInactive = false}) async {
    return menus.where((m) => includeInactive || m.active).toList();
  }

  @override
  Future<Menu> create(MenuInput input) async {
    if (failOnCreate != null) throw failOnCreate!;
    created.add(input);
    final menu = Menu(
      id: menus.length + 1,
      name: input.name,
      category: input.category,
      price: input.price,
      durationMinutes: input.durationMinutes,
      active: true,
      displayOrder: input.displayOrder,
    );
    menus.add(menu);
    return menu;
  }

  @override
  Future<Menu> update(int id, MenuInput input) async => throw UnimplementedError();

  @override
  Future<void> setActive(int id, {required bool active}) async {
    final index = menus.indexWhere((m) => m.id == id);
    final old = menus[index];
    menus[index] = Menu(
      id: old.id,
      name: old.name,
      category: old.category,
      price: old.price,
      durationMinutes: old.durationMinutes,
      active: active,
      displayOrder: old.displayOrder,
    );
  }
}

Menu _menu(int id, String name, {int price = 20000, int minutes = 60, bool active = true}) {
  return Menu(
    id: id,
    name: name,
    category: MenuCategory.cut,
    price: price,
    durationMinutes: minutes,
    active: active,
    displayOrder: id,
  );
}

Future<void> _pumpList(WidgetTester tester, FakeMenuRepository repository) async {
  await tester.pumpWidget(MaterialApp(home: MenuListPage(repository: repository)));
  await tester.pumpAndSettle(); // 서버 응답(Future)과 애니메이션이 끝날 때까지 기다린다
}

void main() {
  testWidgets('메뉴 목록에 이름, 카테고리, 시간, 가격이 보인다', (tester) async {
    final repo = FakeMenuRepository([_menu(1, '커트'), _menu(2, '펌', price: 80000, minutes: 150)]);

    await _pumpList(tester, repo);

    expect(find.text('커트'), findsOneWidget);
    expect(find.text('20,000원'), findsOneWidget);
    expect(find.text('커트 · 1시간'), findsOneWidget); // 카테고리 라벨(커트) · 소요 시간
    expect(find.text('80,000원'), findsOneWidget);
    expect(find.textContaining('2시간 30분'), findsOneWidget);
  });

  testWidgets('판매 중지 메뉴는 기본으로 숨기고, 스위치를 켜면 "판매 중지"로 보여준다', (tester) async {
    final repo = FakeMenuRepository([_menu(1, '커트'), _menu(2, '옛날 펌', active: false)]);

    await _pumpList(tester, repo);
    expect(find.text('옛날 펌'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('옛날 펌'), findsOneWidget);
    expect(find.textContaining('판매 중지'), findsWidgets);
  });

  testWidgets('메뉴가 없으면 안내 문구를 보여준다', (tester) async {
    await _pumpList(tester, FakeMenuRepository([]));

    expect(find.textContaining('등록된 메뉴가 없어요'), findsOneWidget);
  });

  testWidgets('메뉴 추가: 폼을 채워 저장하면 목록에 새 메뉴가 나타난다', (tester) async {
    final repo = FakeMenuRepository([_menu(1, '커트')]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('메뉴 추가'));
    await tester.pumpAndSettle();

    // 입력 칸은 위에서부터: 이름, (카테고리 드롭다운), 가격, 소요 시간, 표시 순서
    await tester.enterText(find.byType(TextFormField).at(0), '염색');
    await tester.enterText(find.byType(TextFormField).at(1), '70000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.created.single.name, '염색');
    expect(repo.created.single.price, 70000);
    expect(repo.created.single.durationMinutes, 60); // 기본값
    expect(repo.created.single.displayOrder, 2); // 마지막 순서(1) + 1
    // 폼이 닫히고 목록이 새로고침되어 새 메뉴가 보인다
    expect(find.text('메뉴 추가'), findsOneWidget); // 목록의 FAB 라벨(폼 제목도 "메뉴 추가"였으므로 하나만 있으면 폼이 닫힌 것)
    expect(find.text('70,000원'), findsOneWidget);
  });

  testWidgets('폼 검증: 이름이 비어 있으면 안내하고 서버로 보내지 않는다', (tester) async {
    final repo = FakeMenuRepository([]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('메뉴 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '20000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('메뉴 이름을 입력해 주세요'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('폼 검증: 소요 시간이 범위를 벗어나면 안내한다', (tester) async {
    final repo = FakeMenuRepository([]);
    await _pumpList(tester, repo);

    await tester.tap(find.text('메뉴 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '염색');
    await tester.enterText(find.byType(TextFormField).at(1), '70000');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('1분에서 720분 사이로 입력해 주세요'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('서버가 거절하면 에러 메시지를 보여주고 폼에 머문다', (tester) async {
    final repo = FakeMenuRepository([])..failOnCreate = ApiException(400, '메뉴 이름이 올바르지 않습니다.');
    await _pumpList(tester, repo);

    await tester.tap(find.text('메뉴 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '염색');
    await tester.enterText(find.byType(TextFormField).at(1), '70000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('메뉴 이름이 올바르지 않습니다.'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget); // 폼이 그대로 남아 있다
  });

  testWidgets('판매 중지를 누르면 목록에서 사라진다', (tester) async {
    final repo = FakeMenuRepository([_menu(1, '커트'), _menu(2, '펌')]);
    await _pumpList(tester, repo);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('판매 중지'));
    await tester.pumpAndSettle();

    expect(find.text('커트'), findsNothing);
    expect(find.text('펌'), findsOneWidget);
  });
}
