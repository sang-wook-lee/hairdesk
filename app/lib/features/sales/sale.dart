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

/// 결제창에서 입력한 값. 결제 대화상자가 이것을 돌려주고, 저장소가 서버로 보낸다.
class PaymentInput {
  const PaymentInput({required this.amount, required this.method, this.memo});

  final int amount;
  final PaymentMethod method;
  final String? memo;
}
