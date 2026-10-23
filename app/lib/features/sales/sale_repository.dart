import '../../core/api_client.dart';
import '../../core/kst.dart';
import 'sale.dart';

/// 매출(결제) 데이터를 서버와 주고받는 곳.
class SaleRepository {
  SaleRepository(this._api);

  final ApiClient _api;

  /// 예약에 대한 결제 등록. 서버가 예약을 자동으로 "완료" 처리한다. (ADR 0004: 결제 = 시술 완료)
  /// 이미 결제된 예약이거나 취소/노쇼된 예약이면 서버가 409를 준다.
  /// 고객과 메뉴는 예약에서 가져오므로 보내지 않는다. 결제 시각을 생략하면 서버가 "지금"으로 기록한다.
  Future<Sale> create({
    required int reservationId,
    required int amount,
    required PaymentMethod method,
    String? memo,
  }) async {
    final json = await _api.postJson('/api/sales', body: {
      'reservationId': reservationId,
      'amount': amount,
      'paymentMethod': method.apiValue,
      'memo': ?memo,
    });
    return Sale.fromJson(json as Map<String, dynamic>);
  }

  /// [from]~[to] 날짜(양쪽 포함, 서울 기준)의 총 매출과 건수. 매출이 없는 기간은 0원 0건이다.
  Future<SalesSummary> summarize(DateTime from, DateTime to) async {
    final json = await _api.getJson(
      '/api/sales/summary',
      query: {'from': formatIsoDate(from), 'to': formatIsoDate(to)},
    );
    return SalesSummary.fromJson(json as Map<String, dynamic>);
  }
}
