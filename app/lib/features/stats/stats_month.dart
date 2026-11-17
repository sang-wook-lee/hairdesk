import 'dart:math' as math;

/// 날짜 범위. [from]과 [to]를 모두 포함한다. (서버 API의 from~to와 같은 의미)
/// 둘 다 시각 없는 서울 날짜다: DateTime(2026, 10, 1) 형태.
class DateRange {
  const DateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) => other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DateRange($from ~ $to)';
}

/// 통계 화면이 보고 있는 "한 달". 2026년 10월처럼 연·월 한 쌍이다.
///
/// 달 이동, 달의 시작/끝 날짜, "지난달과 공정하게 비교할 기간" 계산을 한 곳에 모은다.
/// 화면 상태에는 이 값 하나만 들고 있으면 나머지는 전부 여기서 계산된다.
/// 모든 날짜는 서울 기준이다. "오늘"은 직접 구하지 않고 매번 인자로 받는다. (테스트에서 날짜를 고정하려고)
class StatsMonth {
  const StatsMonth(this.year, this.month) : assert(month >= 1 && month <= 12, 'month는 1~12');

  /// [date]가 속한 달
  factory StatsMonth.containing(DateTime date) => StatsMonth(date.year, date.month);

  final int year;
  final int month;

  /// 그 달 1일
  DateTime get firstDay => DateTime(year, month, 1);

  /// 그 달 마지막 날. DateTime은 "다음 달 0일"을 "이번 달 말일"로 계산해 준다 (28/29/30/31일 자동).
  DateTime get lastDay => DateTime(year, month + 1, 0);

  /// 그 달 전체 기간
  DateRange get range => DateRange(firstDay, lastDay);

  StatsMonth get previous => month == 1 ? StatsMonth(year - 1, 12) : StatsMonth(year, month - 1);

  StatsMonth get next => month == 12 ? StatsMonth(year + 1, 1) : StatsMonth(year, month + 1);

  /// "2026년 10월"
  String get label => '$year년 $month월';

  bool isAfter(StatsMonth other) => year > other.year || (year == other.year && month > other.month);

  /// [today]가 이 달 안에 있는가 (= 아직 끝나지 않은 달인가)
  bool isCurrent(DateTime today) => this == StatsMonth.containing(today);

  /// 다음 달로 갈 수 있는가. 아직 오지 않은 미래의 달로는 갈 수 없다.
  bool canGoNext(DateTime today) => !next.isAfter(StatsMonth.containing(today));

  /// 이 달의 매출과 "공정하게" 비교할 이전 기간.
  ///
  /// - 이미 끝난 달: 직전 달 전체. (예: 9월 ↔ 8월 전체)
  /// - 아직 진행 중인 이번 달: 직전 달의 "같은 날짜까지". (예: 오늘이 10월 17일이면 9월 1일~17일)
  ///   이번 달은 17일치뿐인데 지난달 한 달 전체와 비교하면 달 초마다 큰 감소처럼 보이기 때문이다.
  ///   직전 달에 같은 날짜가 없으면(3월 31일 ↔ 2월) 직전 달 말일까지로 자른다.
  DateRange comparisonRange(DateTime today) {
    final prev = previous;
    if (!isCurrent(today)) return prev.range;
    final day = math.min(today.day, prev.lastDay.day);
    return DateRange(prev.firstDay, DateTime(prev.year, prev.month, day));
  }

  /// 화면에 쓸 비교 기준 이름. [comparisonRange]와 같은 기준으로 정해진다.
  String comparisonLabel(DateTime today) => isCurrent(today) ? '지난달 같은 기간 대비' : '전월 대비';

  @override
  bool operator ==(Object other) => other is StatsMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'StatsMonth($year-${month.toString().padLeft(2, '0')})';
}
