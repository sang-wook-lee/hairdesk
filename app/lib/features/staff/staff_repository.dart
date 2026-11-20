import '../../core/api_client.dart';
import 'staff.dart';

/// 직원 데이터를 서버와 주고받는 곳. 메뉴 저장소와 같은 모양이다.
class StaffRepository {
  StaffRepository(this._api);

  final ApiClient _api;

  /// 직원 목록(직원 번호순). 기본은 근무 중인 직원만, [includeInactive]가 true면 근무를 마친 직원도.
  Future<List<Staff>> fetchAll({bool includeInactive = false}) async {
    final json = await _api.getJson(
      '/api/staff',
      query: {'includeInactive': includeInactive.toString()},
    );
    return (json as List<dynamic>)
        .map((item) => Staff.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 새 직원 등록. 이름·직책이 같은 직원이 있어도 등록된다.
  Future<Staff> create(StaffInput input) async {
    final json = await _api.postJson('/api/staff', body: input.toJson());
    return Staff.fromJson(json as Map<String, dynamic>);
  }

  /// 이름과 직책 수정.
  Future<Staff> update(int id, StaffInput input) async {
    final json = await _api.putJson('/api/staff/$id', body: input.toJson());
    return Staff.fromJson(json as Map<String, dynamic>);
  }

  /// 근무 재개(true) / 근무 종료(false). 삭제 대신 쓴다: 과거 예약·매출 기록을 보존하려고.
  /// 모든 직원이 같은 규칙이다. 마지막 근무 직원도 종료할 수 있고, 실수는 재개로 되돌린다.
  Future<void> setActive(int id, {required bool active}) async {
    await _api.postJson('/api/staff/$id/${active ? 'activate' : 'deactivate'}');
  }
}
