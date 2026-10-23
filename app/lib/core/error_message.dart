import 'api_client.dart';

/// 예외를 사용자에게 보여줄 한글 문장으로 바꾼다.
/// 서버가 알려준 에러(예: 409 "이미 예약이 있습니다")는 그 문장 그대로,
/// 그 외(서버 꺼짐, 인터넷 끊김, CORS 차단 등)는 연결 문제로 안내한다.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return '서버에 연결할 수 없습니다. 서버가 켜져 있는지 확인해 주세요.';
}
