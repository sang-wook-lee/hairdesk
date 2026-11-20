/// 서버에서 받은 직원(담당자) 한 명. (백엔드 ADR 0010, 0011)
/// "주인" 같은 특별한 직원은 없다. 모든 직원이 같은 규칙을 따른다.
class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.position,
    required this.active,
  });

  /// 직원 번호. 이름·직책이 같은 직원이 있을 수 있어서, 직원을 구분하는 것은 이 번호뿐이다.
  final int id;
  final String name;
  final String position; // 직책 (원장, 실장, 디자이너 ...). 자유 입력. "원장"은 여러 명일 수 있다
  final bool active; // false면 근무를 마친 직원

  /// 화면에 보여줄 이름. 동명이인을 구별할 수 있게 번호를 함께 적는다. 예: "이지수 (#2)"
  String get displayName => formatStaffName(name, id);

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as int,
      name: json['name'] as String,
      position: json['position'] as String,
      active: json['active'] as bool,
    );
  }
}

/// "이름 (#번호)". 예약처럼 직원 이름만 가지고 있는 곳에서도 같은 모양으로 보이도록 따로 뺐다.
String formatStaffName(String name, int id) => '$name (#$id)';

/// 직원 등록·수정 때 서버로 보내는 값. 근무 여부는 여기서 보내지 않는다.
/// ("근무 종료/재개" 요청으로만 바꾼다)
class StaffInput {
  const StaffInput({required this.name, required this.position});

  final String name;
  final String position;

  Map<String, dynamic> toJson() => {'name': name, 'position': position};
}
