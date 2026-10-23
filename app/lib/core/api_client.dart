import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서버 주소. 개발 중에는 내 컴퓨터의 Spring Boot 서버.
/// 배포할 때는 실제 서버 주소로 바꿔야 한다. (나중에 빌드 설정으로 분리 예정)
const String apiBaseUrl = 'http://localhost:8080';

/// 서버가 에러(4xx/5xx)로 응답했을 때 던지는 예외.
/// 백엔드의 에러 응답은 { "status": 409, "detail": "해당 시간에 이미 예약이 있습니다." } 형식이라
/// 화면에 그대로 보여줄 수 있는 [message]를 꺼내 담는다.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 서버와 JSON을 주고받는 창구. 화면 코드가 http 패키지를 직접 만지지 않게 한다.
/// (주소, 한글 처리, 에러 변환 규칙이 이 한 곳에만 있으면 나중에 바꾸기 쉽다)
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// GET 요청을 보내고 JSON을 Dart 객체(Map 또는 List)로 돌려준다.
  /// [query]에 넣은 값은 ?from=2026-10-01 같은 주소 뒤 파라미터가 된다.
  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final response = await _http.get(uri);
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    // response.body를 쓰면 안 된다: 서버가 charset을 알려주지 않으면 http 패키지가
    // 한글을 latin1로 잘못 읽어 글자가 깨진다. 바이트를 직접 UTF-8로 풀어야 한다.
    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    // 백엔드의 ProblemDetail 형식에서 사람이 읽을 메시지를 꺼낸다.
    final detail = (json is Map && json['detail'] is String)
        ? json['detail'] as String
        : '요청에 실패했습니다. (${response.statusCode})';
    throw ApiException(response.statusCode, detail);
  }
}
