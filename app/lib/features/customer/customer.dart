/// 서버에서 받은 고객 카드.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.memo,
  });

  final int id;
  final String name;
  final String phone; // 숫자만 (01012345678). 하이픈은 보여줄 때 붙인다. (core/format.dart의 formatPhone)
  final String? memo;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      memo: json['memo'] as String?,
    );
  }
}

/// 고객 등록 때 서버로 보내는 값.
/// 성별은 선택 입력이고 문자 수신 동의는 보내지 않는다(서버 기본값 "동의 안 함", ADR 0002).
class CustomerInput {
  const CustomerInput({required this.name, required this.phone, this.memo});

  final String name;
  final String phone; // 하이픈이 있어도 서버가 숫자만 남긴다
  final String? memo;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (memo != null) 'memo': memo, // 값이 있을 때만 키를 넣는다
      };
}
