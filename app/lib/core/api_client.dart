import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서버 주소. 빌드할 때 `--dart-define=API_BASE_URL=주소`로 바꿀 수 있고, 안 주면 내 컴퓨터의 서버다.
///
/// 예) 폰으로 볼 때: flutter build web --dart-define=API_BASE_URL=http://192.168.219.108:8080
/// (폰에게 "localhost"는 폰 자신이라서, 서버가 있는 PC의 주소를 알려줘야 한다)
///
/// String.fromEnvironment는 "빌드 시점"에 값이 굳는다. 실행 중에는 바꿀 수 없다.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

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

  /// POST 요청. [body]는 Map처럼 JSON으로 바꿀 수 있는 객체. 본문이 필요 없으면 생략한다.
  /// 응답 본문이 비어 있으면(204 등) null을 돌려준다.
  Future<dynamic> postJson(String path, {Object? body}) => _send('POST', path, body);

  /// PUT 요청 (전체 수정).
  Future<dynamic> putJson(String path, {required Object body}) => _send('PUT', path, body);

  /// PATCH 요청 (일부만 수정). 예: 예약 시간만 바꾸기.
  Future<dynamic> patchJson(String path, {required Object body}) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, Object? body) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      // 글자 대신 UTF-8 바이트로 직접 보낸다. 한글이 어떤 환경에서도 같게 전달된다.
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
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
