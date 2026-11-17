import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/stats/stats_month.dart';

void main() {
  group('달의 시작과 끝', () {
    test('30일과 31일인 달의 마지막 날', () {
      expect(const StatsMonth(2026, 10).firstDay, DateTime(2026, 10, 1));
      expect(const StatsMonth(2026, 10).lastDay, DateTime(2026, 10, 31));
      expect(const StatsMonth(2026, 9).lastDay, DateTime(2026, 9, 30));
    });

    test('2월은 윤년이면 29일, 아니면 28일', () {
      expect(const StatsMonth(2028, 2).lastDay, DateTime(2028, 2, 29)); // 윤년
      expect(const StatsMonth(2026, 2).lastDay, DateTime(2026, 2, 28));
    });

    test('12월은 31일에 끝나고, range는 1일~말일이다', () {
      expect(const StatsMonth(2026, 12).lastDay, DateTime(2026, 12, 31));
      expect(const StatsMonth(2026, 12).range, DateRange(DateTime(2026, 12, 1), DateTime(2026, 12, 31)));
    });

    test('어떤 날짜가 속한 달을 찾는다', () {
      expect(StatsMonth.containing(DateTime(2026, 10, 31)), const StatsMonth(2026, 10));
      expect(StatsMonth.containing(DateTime(2027, 1, 1)), const StatsMonth(2027, 1));
    });

    test('1~12월 밖의 달은 만들 수 없다', () {
      expect(() => StatsMonth(2026, 0), throwsA(isA<AssertionError>()));
      expect(() => StatsMonth(2026, 13), throwsA(isA<AssertionError>()));
    });
  });

  group('달 이동', () {
    test('이전/다음 달', () {
      expect(const StatsMonth(2026, 10).previous, const StatsMonth(2026, 9));
      expect(const StatsMonth(2026, 10).next, const StatsMonth(2026, 11));
    });

    test('해가 바뀌는 경계: 1월의 이전은 작년 12월, 12월의 다음은 내년 1월', () {
      expect(const StatsMonth(2026, 1).previous, const StatsMonth(2025, 12));
      expect(const StatsMonth(2026, 12).next, const StatsMonth(2027, 1));
    });

    test('미래의 달로는 갈 수 없다: 이번 달에서는 다음 달로 못 가고, 지난 달에서는 갈 수 있다', () {
      final today = DateTime(2026, 11, 17);

      expect(const StatsMonth(2026, 11).canGoNext(today), isFalse); // 이번 달 → 12월(미래)
      expect(const StatsMonth(2026, 10).canGoNext(today), isTrue); // 10월 → 11월(이번 달)
      expect(const StatsMonth(2025, 12).canGoNext(today), isTrue);
    });

    test('해가 바뀌어도 미래 판정이 맞다: 오늘이 1월이면 작년 12월에서만 다음으로 갈 수 있다', () {
      final today = DateTime(2027, 1, 5);

      expect(const StatsMonth(2026, 12).canGoNext(today), isTrue); // 12월 → 1월(이번 달)
      expect(const StatsMonth(2027, 1).canGoNext(today), isFalse);
    });

    test('isAfter는 연도를 먼저, 그다음 월을 비교한다', () {
      expect(const StatsMonth(2027, 1).isAfter(const StatsMonth(2026, 12)), isTrue);
      expect(const StatsMonth(2026, 12).isAfter(const StatsMonth(2027, 1)), isFalse);
      expect(const StatsMonth(2026, 10).isAfter(const StatsMonth(2026, 10)), isFalse);
    });

    test('이번 달인지 알 수 있다', () {
      expect(const StatsMonth(2026, 11).isCurrent(DateTime(2026, 11, 30)), isTrue);
      expect(const StatsMonth(2026, 11).isCurrent(DateTime(2026, 12, 1)), isFalse);
    });
  });

  group('지난달과 공정하게 비교할 기간', () {
    test('이번 달은 지난달의 "같은 날짜까지"와 비교한다 (오늘 11/17 → 10/1~10/17)', () {
      final range = const StatsMonth(2026, 11).comparisonRange(DateTime(2026, 11, 17));

      expect(range, DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 17)));
    });

    test('이미 끝난 달은 직전 달 전체와 비교한다 (10월 ↔ 9월 전체)', () {
      final range = const StatsMonth(2026, 10).comparisonRange(DateTime(2026, 11, 17));

      expect(range, DateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    });

    test('오늘이 1일이면 지난달 1일 하루와 비교한다', () {
      final range = const StatsMonth(2026, 11).comparisonRange(DateTime(2026, 11, 1));

      expect(range, DateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 1)));
    });

    test('지난달에 같은 날짜가 없으면 지난달 말일까지로 자른다 (3월 31일 ↔ 2월 28일)', () {
      final range = const StatsMonth(2026, 3).comparisonRange(DateTime(2026, 3, 31));

      expect(range, DateRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
    });

    test('윤년 2월로 자를 때는 29일까지', () {
      final range = const StatsMonth(2028, 3).comparisonRange(DateTime(2028, 3, 31));

      expect(range, DateRange(DateTime(2028, 2, 1), DateTime(2028, 2, 29)));
    });

    test('1월의 비교 기간은 작년 12월이다', () {
      final range = const StatsMonth(2027, 1).comparisonRange(DateTime(2027, 1, 10));

      expect(range, DateRange(DateTime(2026, 12, 1), DateTime(2026, 12, 10)));
    });

    test('비교 기준 이름은 이번 달이면 "지난달 같은 기간 대비", 끝난 달이면 "전월 대비"', () {
      final today = DateTime(2026, 11, 17);

      expect(const StatsMonth(2026, 11).comparisonLabel(today), '지난달 같은 기간 대비');
      expect(const StatsMonth(2026, 10).comparisonLabel(today), '전월 대비');
    });
  });

  test('같은 연·월이면 같은 값이고, 화면에 보일 이름은 "2026년 10월"이다', () {
    expect(const StatsMonth(2026, 10), const StatsMonth(2026, 10));
    expect({StatsMonth(2026, 10), StatsMonth(2026, 10)}.length, 1); // 집합에서도 하나로 취급
    expect(const StatsMonth(2026, 10), isNot(const StatsMonth(2026, 11)));
    expect(const StatsMonth(2026, 10).label, '2026년 10월');
  });
}
