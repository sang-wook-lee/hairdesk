import '../../core/api_client.dart';
import 'menu.dart';

/// 메뉴 데이터를 서버와 주고받는 곳. 화면은 이 클래스만 알고, API 주소나 JSON 모양은 모른다.
/// (주소가 바뀌어도 이 파일만 고치면 된다)
class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  /// 메뉴 목록. 기본은 판매 중인 메뉴만, [includeInactive]가 true면 판매 중지 메뉴도.
  Future<List<Menu>> fetchAll({bool includeInactive = false}) async {
    final json = await _api.getJson(
      '/api/menus',
      query: {'includeInactive': includeInactive.toString()},
    );
    return (json as List<dynamic>)
        .map((item) => Menu.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Menu> create(MenuInput input) async {
    final json = await _api.postJson('/api/menus', body: input.toJson());
    return Menu.fromJson(json as Map<String, dynamic>);
  }

  Future<Menu> update(int id, MenuInput input) async {
    final json = await _api.putJson('/api/menus/$id', body: input.toJson());
    return Menu.fromJson(json as Map<String, dynamic>);
  }

  /// 판매 중지(false) / 재개(true). 삭제 대신 쓴다: 과거 매출 기록을 보존하려고.
  Future<void> setActive(int id, {required bool active}) async {
    await _api.postJson('/api/menus/$id/${active ? 'activate' : 'deactivate'}');
  }
}
