import '../../core/api_client.dart';
import '../../core/kst.dart';
import 'stats.dart';

/// 통계 데이터를 서버에서 가져오는 곳. 모두 조회(GET)뿐이다.
///
/// 날짜는 서울 기준이고 [from]~[to]는 양쪽 포함이다. (서버 규칙: ADR 0005)
/// 기간 매출 요약(총액, 결제수단별)은 매출 쪽 API라서 SaleRepository.summarize를 쓴다.
class StatsRepository {
  StatsRepository(this._api);

  final ApiClient _api;

  /// 일별 매출. 매출이 없는 날도 0으로 채워져 오고, 기간은 최대 366일이다.
  Future<List<DailySales>> dailySales(DateTime from, DateTime to) async {
    final json = await _api.getJson('/api/stats/sales/daily', query: _range(from, to));
    return _list(json, DailySales.fromJson);
  }

  /// 해당 연도의 월별 매출. 항상 1~12월 12개가 온다.
  Future<List<MonthlySales>> monthlySales(int year) async {
    final json = await _api.getJson('/api/stats/sales/monthly', query: {'year': '$year'});
    return _list(json, MonthlySales.fromJson);
  }

  /// 메뉴별 매출, 총액이 큰 순.
  Future<List<MenuSales>> salesByMenu(DateTime from, DateTime to) async {
    final json = await _api.getJson('/api/stats/sales/by-menu', query: _range(from, to));
    return _list(json, MenuSales.fromJson);
  }

  /// 신규/재방문 고객 수.
  Future<CustomerStats> customerStats(DateTime from, DateTime to) async {
    final json = await _api.getJson('/api/stats/customers', query: _range(from, to));
    return CustomerStats.fromJson(json as Map<String, dynamic>);
  }

  /// 예약 상태별 건수와 노쇼율. (예약 시작 시각이 기간에 드는 예약 기준)
  Future<ReservationStats> reservationStats(DateTime from, DateTime to) async {
    final json = await _api.getJson('/api/stats/reservations', query: _range(from, to));
    return ReservationStats.fromJson(json as Map<String, dynamic>);
  }

  Map<String, String> _range(DateTime from, DateTime to) =>
      {'from': formatIsoDate(from), 'to': formatIsoDate(to)};

  /// JSON 배열의 각 원소를 모델로 바꾼다. 다섯 메서드가 같은 변환을 하므로 한 곳에 모았다.
  List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
    return [
      for (final item in json as List<dynamic>) fromJson(item as Map<String, dynamic>),
    ];
  }
}
