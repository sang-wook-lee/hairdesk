/// 서버의 페이지 응답 한 쪽. 서버 형식:
/// { "content": [...], "page": 0, "size": 20, "totalElements": 45, "totalPages": 3 }
///
/// 항목을 어떻게 읽을지는 호출하는 쪽이 [fromJson]에 넘긴다. (고객 방문 이력, 나중에 고객 목록 등에서 같이 쓴다)
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> items;
  final int page; // 0부터 시작
  final int totalElements; // 전체 항목 수 (이 페이지만이 아니라 전부)
  final int totalPages;

  /// 이 뒤에 더 불러올 페이지가 있는가. ("더 보기" 버튼을 보일지 결정한다)
  bool get hasMore => page + 1 < totalPages;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PageResult(
      items: [
        for (final item in json['content'] as List<dynamic>) fromJson(item as Map<String, dynamic>),
      ],
      page: json['page'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
