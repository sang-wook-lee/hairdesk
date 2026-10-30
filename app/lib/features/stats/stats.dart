// 통계 API 응답을 담는 모델들. 서버의 stats/dto 와 같은 이름, 같은 필드다.
// 화면은 JSON을 직접 만지지 않고 이 객체만 쓴다.

/// 하루 매출. 서버가 매출 없는 날도 0으로 채워 주므로, 기간의 모든 날짜가 들어 있다.
class DailySales {
  const DailySales({required this.date, required this.totalAmount, required this.count});

  /// 서울 기준 날짜 (시각 없음). DateTime(2026, 10, 1) 형태.
  final DateTime date;
  final int totalAmount; // 원
  final int count; // 결제 건수

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: _parseDate(json['date'] as String),
      totalAmount: json['totalAmount'] as int,
      count: json['count'] as int,
    );
  }
}

/// 한 달 매출. 서버는 해당 연도 1~12월을 항상 12개 준다 (없는 달은 0).
class MonthlySales {
  const MonthlySales({required this.month, required this.totalAmount, required this.count});

  /// "2026-10" 형식
  final String month;
  final int totalAmount;
  final int count;

  factory MonthlySales.fromJson(Map<String, dynamic> json) {
    return MonthlySales(
      month: json['month'] as String,
      totalAmount: json['totalAmount'] as int,
      count: json['count'] as int,
    );
  }
}

/// 메뉴별 매출 한 줄. 서버가 총액이 큰 순으로 정렬해서 준다.
/// 이름은 메뉴의 "현재" 이름이다 (이름을 바꿔도 매출이 쪼개지지 않게 id로 묶는다. ADR 0005).
class MenuSales {
  const MenuSales({
    required this.menuId,
    required this.menuName,
    required this.totalAmount,
    required this.count,
  });

  final int menuId;
  final String menuName;
  final int totalAmount;
  final int count;

  factory MenuSales.fromJson(Map<String, dynamic> json) {
    return MenuSales(
      menuId: json['menuId'] as int,
      menuName: json['menuName'] as String,
      totalAmount: json['totalAmount'] as int,
      count: json['count'] as int,
    );
  }
}

/// 기간 내 고객 수. 정의는 ADR 0005:
/// 신규 = 기간 시작 전 결제 이력이 없는 고객, 재방문 = 있는 고객, 한 사람은 한 번만 센다.
class CustomerStats {
  const CustomerStats({
    required this.totalCustomers,
    required this.newCustomers,
    required this.returningCustomers,
  });

  final int totalCustomers; // = newCustomers + returningCustomers
  final int newCustomers;
  final int returningCustomers;

  factory CustomerStats.fromJson(Map<String, dynamic> json) {
    return CustomerStats(
      totalCustomers: json['totalCustomers'] as int,
      newCustomers: json['newCustomers'] as int,
      returningCustomers: json['returningCustomers'] as int,
    );
  }
}

/// 기간 내 예약 현황. 노쇼율 = 노쇼 / (완료 + 노쇼). 결과가 난 예약이 없으면 0.0 (ADR 0005).
class ReservationStats {
  const ReservationStats({
    required this.booked,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.noShowRate,
  });

  final int booked;
  final int completed;
  final int cancelled;
  final int noShow;

  /// 0.0 ~ 1.0. 0.25면 25%.
  final double noShowRate;

  factory ReservationStats.fromJson(Map<String, dynamic> json) {
    return ReservationStats(
      booked: json['booked'] as int,
      completed: json['completed'] as int,
      cancelled: json['cancelled'] as int,
      noShow: json['noShow'] as int,
      // 서버가 0.0 대신 0으로 보내도(JSON에는 정수/실수 구분이 모호하다) 읽을 수 있게 num으로 받는다.
      noShowRate: (json['noShowRate'] as num).toDouble(),
    );
  }
}

/// "2026-10-01" → DateTime(2026, 10, 1). 시각 없는 날짜라서 시간대 변환을 하지 않는다.
DateTime _parseDate(String isoDate) {
  final parts = isoDate.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
