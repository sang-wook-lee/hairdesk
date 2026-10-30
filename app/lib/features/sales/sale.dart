/// 결제 수단. 서버(PaymentMethod)와 같은 값을 쓴다.
enum PaymentMethod {
  card('CARD', '카드'),
  cash('CASH', '현금'),
  transfer('TRANSFER', '계좌이체'),
  etc('ETC', '기타');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String value) =>
      PaymentMethod.values.firstWhere((m) => m.apiValue == value);
}

/// 서버에 등록된 매출(결제) 한 건.
class Sale {
  const Sale({
    required this.id,
    required this.price,
    required this.amount,
    required this.paymentMethod,
  });

  final int id;
  final int price; // 결제 당시 정가
  final int amount; // 실제 받은 금액
  final PaymentMethod paymentMethod;

  /// 할인액 = 정가 - 받은 금액
  int get discount => price - amount;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as int,
      price: json['price'] as int,
      amount: json['amount'] as int,
      paymentMethod: PaymentMethod.fromApi(json['paymentMethod'] as String),
    );
  }
}

/// 결제수단별 합계 한 줄 (예: 카드 713,000원 14건)
class MethodTotal {
  const MethodTotal({required this.method, required this.totalAmount, required this.count});

  final PaymentMethod method;
  final int totalAmount;
  final int count;

  factory MethodTotal.fromJson(Map<String, dynamic> json) {
    return MethodTotal(
      method: PaymentMethod.fromApi(json['method'] as String),
      totalAmount: json['totalAmount'] as int,
      count: json['count'] as int,
    );
  }
}

/// 기간 매출 요약: 총액, 건수, 결제수단별 내역. (서버의 /api/sales/summary 응답)
/// 홈 화면은 총액과 건수만 쓰고, 통계 화면은 [byMethod]까지 쓴다.
class SalesSummary {
  const SalesSummary({
    required this.totalAmount,
    required this.count,
    this.byMethod = const [],
  });

  final int totalAmount; // 원
  final int count; // 결제 건수

  /// 매출이 있는 결제수단만 들어 있다. 매출이 없는 기간이면 빈 목록이다.
  final List<MethodTotal> byMethod;

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    // byMethod가 응답에 없어도(예전 응답, 테스트용 가짜) 빈 목록으로 읽는다.
    final methods = (json['byMethod'] as List<dynamic>?) ?? const [];
    return SalesSummary(
      totalAmount: json['totalAmount'] as int,
      count: json['count'] as int,
      byMethod: [
        for (final m in methods) MethodTotal.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

/// 결제창에서 입력한 값. 결제 대화상자가 이것을 돌려주고, 저장소가 서버로 보낸다.
class PaymentInput {
  const PaymentInput({required this.amount, required this.method, this.memo});

  final int amount;
  final PaymentMethod method;
  final String? memo;
}
