import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/kst.dart';

void main() {
  group('서울 시각 변환', () {
    test('오프셋이 붙은 서버 시각을 서울 시:분으로 보여준다', () {
      final t = DateTime.parse('2026-10-01T14:05:00+09:00');

      expect(formatHm(t), '14:05');
    });

    test('UTC 시각도 같은 순간이면 같은 서울 시각이다', () {
      final t = DateTime.parse('2026-10-01T05:05:00Z'); // 서울 14:05

      expect(formatHm(t), '14:05');
    });

    test('서울 자정 근처: UTC로는 전날이어도 서울 날짜로 계산한다', () {
      final t = DateTime.parse('2026-10-01T15:30:00Z'); // 서울 10/2 00:30

      final k = toKst(t);

      expect(formatIsoDate(k), '2026-10-02');
      expect(formatHm(t), '00:30');
    });
  });

  group('서울 기준 오늘', () {
    test('UTC로는 전날이어도 서울 날짜로 오늘을 계산한다', () {
      // UTC 9/30 15:30 = 서울 10/1 00:30
      expect(formatIsoDate(kstToday(now: DateTime.parse('2026-09-30T15:30:00Z'))), '2026-10-01');
    });

    test('서울 23:59는 아직 그날이다', () {
      expect(formatIsoDate(kstToday(now: DateTime.parse('2026-10-01T23:59:00+09:00'))), '2026-10-01');
    });
  });

  group('날짜 글자', () {
    test('서버로 보낼 날짜는 0을 채운 yyyy-MM-dd', () {
      expect(formatIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('서버로 보낼 시각은 서울 오프셋(+09:00)을 붙인 형식이다', () {
      expect(formatKstIso(DateTime(2026, 10, 1, 9, 5)), '2026-10-01T09:05:00+09:00');
      // 서버가 이 문자열을 받아 해석한 시각을 다시 서울 시각으로 보면 처음 입력과 같아야 한다 (왕복)
      expect(formatHm(DateTime.parse(formatKstIso(DateTime(2026, 10, 1, 9, 5)))), '09:05');
    });

    test('화면용 날짜에는 한글 요일이 붙는다', () {
      expect(formatKoreanDate(DateTime(2026, 10, 1)), '2026년 10월 1일 (목)');
      expect(formatKoreanDate(DateTime(2026, 10, 4)), '2026년 10월 4일 (일)');
    });
  });
}
