import '../sales/sale.dart';
import '../staff/staff.dart';

/// 고객의 방문 이력 한 줄. 서버의 GET /api/customers/{id}/visits 항목(매출 기록)이다.
///
/// 결제 직후 받는 [Sale]과 따로 둔 이유: Sale은 "방금 결제한 결과"(금액 4개)이고,
/// 이쪽은 이력 화면에 보일 값(언제, 무슨 시술, 누가, 얼마)이라 쓰임이 다르다.
class CustomerVisit {
  const CustomerVisit({
    required this.id,
    required this.menuName,
    required this.staffId,
    required this.staffName,
    required this.staffPosition,
    required this.price,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    this.memo,
  });

  final int id; // 매출 번호
  final String menuName; // 결제 당시 메뉴 이름
  final int staffId;
  final String staffName;
  final String staffPosition;
  final int price; // 결제 당시 정가
  final int amount; // 실제 받은 금액
  final PaymentMethod paymentMethod;
  final DateTime paidAt; // 절대 시각(UTC). 보여줄 때 core/kst.dart를 거친다
  final String? memo;

  /// 할인액 = 정가 - 받은 금액
  int get discount => price - amount;

  /// 담당자를 "이름 (#번호)"로. 동명이인이 있을 수 있어 번호를 함께 보여준다.
  String get staffDisplayName => formatStaffName(staffName, staffId);

  factory CustomerVisit.fromJson(Map<String, dynamic> json) {
    return CustomerVisit(
      id: json['id'] as int,
      menuName: json['menuName'] as String,
      staffId: json['staffId'] as int,
      staffName: json['staffName'] as String,
      staffPosition: json['staffPosition'] as String,
      price: json['price'] as int,
      amount: json['amount'] as int,
      paymentMethod: PaymentMethod.fromApi(json['paymentMethod'] as String),
      paidAt: DateTime.parse(json['paidAt'] as String),
      memo: json['memo'] as String?,
    );
  }
}
