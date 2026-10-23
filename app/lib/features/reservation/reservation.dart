/// 예약 상태. 서버(ReservationStatus)와 같은 값을 쓴다.
enum ReservationStatus {
  booked('BOOKED', '예약'),
  completed('COMPLETED', '완료'),
  cancelled('CANCELLED', '취소'),
  noShow('NO_SHOW', '노쇼');

  const ReservationStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ReservationStatus fromApi(String value) =>
      ReservationStatus.values.firstWhere((s) => s.apiValue == value);
}

/// 서버에서 받은 예약 한 건.
class Reservation {
  const Reservation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.menuId,
    required this.menuName,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.memo,
  });

  final int id;
  final int customerId;
  final String customerName;
  final String customerPhone; // 숫자만 (01012345678)
  final int menuId;
  final String menuName;

  /// 절대 시각(UTC). 화면에 보여줄 때 core/kst.dart로 서울 시각으로 바꾼다.
  final DateTime startAt;
  final DateTime endAt;
  final ReservationStatus status;
  final String? memo; // 없을 수 있다(null)

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as int,
      customerId: json['customerId'] as int,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      menuId: json['menuId'] as int,
      menuName: json['menuName'] as String,
      // "2026-10-01T14:00:00+09:00" → 오프셋을 반영한 UTC 시각
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      status: ReservationStatus.fromApi(json['status'] as String),
      memo: json['memo'] as String?,
    );
  }
}
