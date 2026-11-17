import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/stats/stats_calculations.dart';
import 'package:hairdesk/features/stats/stats_text.dart';

void main() {
  group('changeText', () {
    test('증가는 +, 감소는 -, 0%는 변동 없음', () {
      expect(changeText(const Changed(12)), '+12%');
      expect(changeText(const Changed(-48)), '-48%');
      expect(changeText(const Changed(0)), '변동 없음');
    });

    test('매우 큰 증가율도 그대로 쓴다', () {
      expect(changeText(const Changed(1400)), '+1400%');
    });

    test('비교할 수 없으면 퍼센트 없이 안내만', () {
      expect(changeText(const NoComparison()), '비교할 매출 없음');
    });
  });
}
