import '../../core/api_client.dart';
import '../../core/kst.dart';
import 'reservation.dart';

/// 예약 데이터를 서버와 주고받는 곳.
class ReservationRepository {
  ReservationRepository(this._api);

  final ApiClient _api;

  /// 예약 등록. [startAt]은 "서울에서 시계가 가리키는 시각"(예: DateTime(2026, 10, 23, 14, 0))이다.
  /// 종료 시각은 보내지 않는다: 서버가 메뉴 소요시간으로 계산한다.
  /// 그 시간에 이미 예약이 있으면 서버가 409(ApiException)를 준다.
  Future<Reservation> create({
    required int customerId,
    required int menuId,
    required DateTime startAt,
    String? memo,
  }) async {
    final json = await _api.postJson('/api/reservations', body: {
      'customerId': customerId,
      'menuId': menuId,
      'startAt': formatKstIso(startAt),
      'memo': ?memo, // null이면 키 자체를 보내지 않는다 (Dart 3.8의 null-aware 요소)
    });
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
