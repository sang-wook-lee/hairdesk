/// 시술 카테고리. 서버(MenuCategory)와 같은 값을 쓰고, 화면에 보여줄 한글 이름을 함께 가진다.
///
/// enum도 필드와 생성자를 가질 수 있다(Dart 3). 서버에 보낼 값(apiValue)과
/// 화면용 이름(label)을 한 곳에 모아 두면 둘이 어긋나지 않는다.
enum MenuCategory {
  cut('CUT', '커트'),
  perm('PERM', '펌'),
  color('COLOR', '염색'),
  clinic('CLINIC', '클리닉'),
  etc('ETC', '기타');

  const MenuCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MenuCategory fromApi(String value) =>
      MenuCategory.values.firstWhere((c) => c.apiValue == value);
}

/// 서버에서 받은 시술 메뉴.
class Menu {
  const Menu({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.active,
    required this.displayOrder,
  });

  final int id;
  final String name;
  final MenuCategory category;
  final int price; // 원
  final int durationMinutes;
  final bool active; // false면 판매 중지
  final int displayOrder;

  /// JSON(Map)을 Menu로 바꾼다. factory 생성자 = 새 객체를 만들어 돌려주는 생성자.
  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'] as int,
      name: json['name'] as String,
      category: MenuCategory.fromApi(json['category'] as String),
      price: json['price'] as int,
      durationMinutes: json['durationMinutes'] as int,
      active: json['active'] as bool,
      displayOrder: json['displayOrder'] as int,
    );
  }
}

/// 메뉴 등록/수정 때 서버로 보내는 값. (서버의 MenuRequest와 같은 모양)
/// id나 active는 없다: 등록 때는 서버가 정하고, 판매 중지는 별도 API로 바꾼다.
class MenuInput {
  const MenuInput({
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.displayOrder,
  });

  final String name;
  final MenuCategory category;
  final int price;
  final int durationMinutes;
  final int displayOrder;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.apiValue,
        'price': price,
        'durationMinutes': durationMinutes,
        'displayOrder': displayOrder,
      };
}
