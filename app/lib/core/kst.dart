// 한국 시간(KST, UTC+9) 처리. 시각 변환은 반드시 이 파일을 거친다. (백엔드의 SeoulDates와 같은 역할)
//
// 서버는 "2026-10-01T14:00:00+09:00" 같은 절대 시각을 준다. DateTime.parse는 이것을 UTC로 바꿔 들고 있다.
// 화면에 보여줄 때 기기의 시간대(DateTime.toLocal)를 쓰면 기기 설정에 따라 결과가 달라지므로,
// 항상 +9시간을 직접 더해서 "서울 벽시계 시각"으로 바꾼다.

const Duration _kstOffset = Duration(hours: 9);

/// 서울 기준 오늘 날짜 (시·분 없이 날짜만).
/// [now]를 주면 그 순간을 "지금"으로 본다. 테스트에서 시계를 고정하려고 열어 둔 것이다.
DateTime kstToday({DateTime? now}) {
  final k = (now ?? DateTime.now()).toUtc().add(_kstOffset);
  return DateTime(k.year, k.month, k.day);
}

/// 절대 시각 → 서울 벽시계 시각. 결과의 year/hour 같은 필드가 서울 기준 값이다.
DateTime toKst(DateTime instant) {
  final k = instant.toUtc().add(_kstOffset);
  return DateTime(k.year, k.month, k.day, k.hour, k.minute, k.second);
}

/// 14:05 처럼 시:분 (서울 기준)
String formatHm(DateTime instant) {
  final k = toKst(instant);
  return '${_two(k.hour)}:${_two(k.minute)}';
}

/// 서울 벽시계 시각을 서버가 받는 형식으로: DateTime(2026,10,1,14,0) → "2026-10-01T14:00:00+09:00"
/// (입력은 toKst로 만든 값처럼 "서울에서 시계가 가리키는 시각"이어야 한다)
String formatKstIso(DateTime wallClock) =>
    '${formatIsoDate(wallClock)}T${_two(wallClock.hour)}:${_two(wallClock.minute)}:00+09:00';

/// 서버에 보낼 날짜 "2026-10-01"
String formatIsoDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// 화면에 보여줄 날짜 "2026년 10월 1일 (목)"
String formatKoreanDate(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  // DateTime.weekday: 월요일 = 1 ... 일요일 = 7
  return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
}

String _two(int n) => n.toString().padLeft(2, '0');
