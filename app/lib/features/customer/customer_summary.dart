/// 고객 한 명의 요약. 서버의 GET /api/customers/{id}/summary 응답.
/// 방문은 예약이 아니라 "매출(결제) 기록"으로 센다. 예약 없이 온 손님도 방문이다.
class CustomerSummary {
  const CustomerSummary({
    required this.visitCount,
    required this.totalAmount,
    required this.reservationCount,
    required this.cancelledCount,
    required this.noShowCount,
    this.firstVisitAt,
    this.lastVisitAt,
    this.averageAmount,
    this.lastMenuName,
    this.lastStaffId,
    this.lastStaffName,
    this.lastStaffPosition,
  });

  final int visitCount;
  final int totalAmount; // 원. 결제가 없으면 0
  final int reservationCount; // 예약됨 상태까지 포함한, 만든 예약 전체 수
  final int cancelledCount;
  final int noShowCount;

  /// 아래는 방문(결제)이 한 번도 없으면 null이다. 화면에서 "-" 등으로 처리한다.
  final DateTime? firstVisitAt; // 절대 시각(UTC). 보여줄 때 core/kst.dart를 거친다
  final DateTime? lastVisitAt;
  final int? averageAmount; // 원 단위로 반올림된 평균 결제액
  final String? lastMenuName;
  final int? lastStaffId;
  final String? lastStaffName;
  final String? lastStaffPosition;

  /// 방문이 한 번도 없는 고객인가
  bool get hasVisits => visitCount > 0;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      visitCount: json['visitCount'] as int,
      totalAmount: json['totalAmount'] as int,
      reservationCount: json['reservationCount'] as int,
      cancelledCount: json['cancelledCount'] as int,
      noShowCount: json['noShowCount'] as int,
      firstVisitAt: _parseTime(json['firstVisitAt']),
      lastVisitAt: _parseTime(json['lastVisitAt']),
      averageAmount: json['averageAmount'] as int?,
      lastMenuName: json['lastMenuName'] as String?,
      lastStaffId: json['lastStaffId'] as int?,
      lastStaffName: json['lastStaffName'] as String?,
      lastStaffPosition: json['lastStaffPosition'] as String?,
    );
  }

  static DateTime? _parseTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
