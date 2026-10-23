import '../../core/api_client.dart';
import 'customer.dart';

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

  /// 새 고객 등록. 같은 이름+번호가 이미 있으면 서버가 409를 준다.
  Future<Customer> create(CustomerInput input) async {
    final json = await _api.postJson('/api/customers', body: input.toJson());
    return Customer.fromJson(json as Map<String, dynamic>);
  }
}
