import '../../core/api_client.dart';
import '../../core/kst.dart';
import 'reservation.dart';

/// 예약 데이터를 서버와 주고받는 곳.
class ReservationRepository {
  ReservationRepository(this._api);

  final ApiClient _api;

  /// 예약 등록. [startAt]은 "서울에서 시계가 가리키는 시각"(예: DateTime(2026, 10, 23, 14, 0))이다.
  /// 종료 시각은 보내지 않는다: 서버가 메뉴 소요시간으로 계산한다.
  /// [staffId]는 담당자의 직원 번호다. 생략하면 서버가 매장 주인으로 예약한다.
  /// 그 직원의 그 시간에 이미 예약이 있으면 서버가 409(ApiException)를 준다. 다른 직원의 예약과는 겹쳐도 된다.
  Future<Reservation> create({
    required int customerId,
    required int menuId,
    int? staffId,
    required DateTime startAt,
    String? memo,
  }) async {
    final json = await _api.postJson('/api/reservations', body: {
      'customerId': customerId,
      'menuId': menuId,
      'staffId': ?staffId, // 생략하면 키를 보내지 않는다 → 서버가 매장 주인으로 처리
      'startAt': formatKstIso(startAt),
      'memo': ?memo, // null이면 키 자체를 보내지 않는다 (Dart 3.8의 null-aware 요소)
    });
    return Reservation.fromJson(json as Map<String, dynamic>);
  }

  /// 예약 시간 변경. 소요 시간은 그대로이고 시작 시각만 옮긴다. 다른 예약과 겹치면 409.
  /// "예약" 상태일 때만 가능하다. (이미 완료/취소/노쇼면 409)
  Future<Reservation> reschedule(int id, DateTime startAt) async {
    final json = await _api.patchJson(
      '/api/reservations/$id/time',
      body: {'startAt': formatKstIso(startAt)},
    );
    return Reservation.fromJson(json as Map<String, dynamic>);
  }

  /// 예약 취소. 취소하면 그 시간에 다시 예약을 받을 수 있다.
  Future<Reservation> cancel(int id) => _changeStatus(id, 'cancel');

  /// 노쇼 처리. 이것도 그 시간을 다시 비운다.
  Future<Reservation> markNoShow(int id) => _changeStatus(id, 'no-show');

  // 완료 처리는 따로 없다: 결제(SaleRepository.create)가 예약을 자동으로 완료시킨다.

  Future<Reservation> _changeStatus(int id, String action) async {
    final json = await _api.postJson('/api/reservations/$id/$action');
    return Reservation.fromJson(json as Map<String, dynamic>);
  }

  /// [from]~[to] 날짜(양쪽 포함, 서울 기준)에 시작하는 예약을 시간순으로.
  /// 하루만 보려면 from과 to를 같게 준다. 취소된 예약도 포함된다.
  Future<List<Reservation>> fetchBetween(DateTime from, DateTime to) async {
    final json = await _api.getJson(
      '/api/reservations',
      query: {'from': formatIsoDate(from), 'to': formatIsoDate(to)},
    );
    return (json as List<dynamic>)
        .map((item) => Reservation.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
