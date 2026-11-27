import '../../core/api_client.dart';
import '../../core/page_result.dart';
import '../reservation/reservation.dart';
import 'customer.dart';
import 'customer_summary.dart';
import 'customer_visit.dart';

/// 고객 데이터를 서버와 주고받는 곳.
class CustomerRepository {
  CustomerRepository(this._api);

  final ApiClient _api;

  /// 이름 일부나 번호 일부(뒷자리 4개 등)로 검색한다. [keyword]가 비면 전체(이름순).
  /// 서버는 페이지 단위로 주지만, 예약할 고객을 고르는 용도라 첫 페이지(20명)만 쓴다.
  /// 더 찾으려면 검색어를 더 구체적으로 쓰면 된다.
  Future<List<Customer>> search(String keyword) async {
    final json = await _api.getJson(
      '/api/customers',
      query: {'keyword': keyword.trim(), 'page': '0', 'size': '20'},
    );
    // 응답: { "content": [ ... ], "page": 0, "totalElements": ... }
    final content = (json as Map<String, dynamic>)['content'] as List<dynamic>;
    return content
        .map((item) => Customer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 고객 한 명 조회. 없는 번호면 서버가 404(ApiException)를 준다.
  Future<Customer> findById(int id) async {
    final json = await _api.getJson('/api/customers/$id');
    return Customer.fromJson(json as Map<String, dynamic>);
  }

  /// 고객 요약(방문 횟수, 총 결제액, 첫·최근 방문일, 최근 시술 등). 없는 고객은 404.
  Future<CustomerSummary> fetchSummary(int id) async {
    final json = await _api.getJson('/api/customers/$id/summary');
    return CustomerSummary.fromJson(json as Map<String, dynamic>);
  }

  /// 방문 이력(결제 기록)을 최신순으로 [size]건씩. [page]는 0부터. 없는 고객은 404.
  Future<PageResult<CustomerVisit>> fetchVisits(int id, {int page = 0, int size = 20}) async {
    final json = await _api.getJson(
      '/api/customers/$id/visits',
      query: {'page': '$page', 'size': '$size'},
    );
    return PageResult.fromJson(json as Map<String, dynamic>, CustomerVisit.fromJson);
  }

  /// 고객의 다음 예약: 예약됨 상태인 예약 전부를 시간순으로. 시각이 지났는데 처리 안 된 예약도 들어 있다.
  Future<List<Reservation>> fetchUpcoming(int id) async {
    final json = await _api.getJson('/api/customers/$id/upcoming-reservations');
    return [
      for (final item in json as List<dynamic>) Reservation.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 새 고객 등록. 같은 이름+번호가 이미 있으면 서버가 409를 준다.
  Future<Customer> create(CustomerInput input) async {
    final json = await _api.postJson('/api/customers', body: input.toJson());
    return Customer.fromJson(json as Map<String, dynamic>);
  }
}
