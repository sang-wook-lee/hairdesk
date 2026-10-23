import '../../core/api_client.dart';
import '../../core/kst.dart';
import 'reservation.dart';

/// 예약 데이터를 서버와 주고받는 곳.
class ReservationRepository {
  ReservationRepository(this._api);

  final ApiClient _api;

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
