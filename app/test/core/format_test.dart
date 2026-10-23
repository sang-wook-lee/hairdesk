import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/format.dart';

void main() {
  group('formatWon', () {
    test('천 단위마다 쉼표를 넣는다', () {
      expect(formatWon(0), '0원');
      expect(formatWon(500), '500원');
      expect(formatWon(1000), '1,000원');
      expect(formatWon(20000), '20,000원');
      expect(formatWon(1234567), '1,234,567원');
    });
  });

  group('formatPhone', () {
    test('하이픈을 넣어 읽기 좋게 보여준다', () {
      expect(formatPhone('01012345678'), '010-1234-5678');
      expect(formatPhone('0111234567'), '011-123-4567');
      expect(formatPhone('123'), '123'); // 형식이 다르면 그대로
    });
  });

  group('formatDuration', () {
    test('1시간 미만은 분, 정각은 시간, 나머지는 둘 다 보여준다', () {
      expect(formatDuration(45), '45분');
      expect(formatDuration(60), '1시간');
      expect(formatDuration(90), '1시간 30분');
      expect(formatDuration(120), '2시간');
    });
  });
}
