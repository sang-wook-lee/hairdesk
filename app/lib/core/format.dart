// 화면에 보여줄 글자 만들기. 값은 항상 원본(int)으로 들고 있다가 보여줄 때만 변환한다.

/// 20000 → "20,000원"
String formatWon(int amount) {
  // 정규식 해설: 숫자 사이에서 "뒤에 숫자가 3의 배수 개 남은 자리"마다 쉼표를 넣는다.
  final withCommas = amount.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
  return '$withCommas원';
}

/// 01012345678 → "010-1234-5678", 0101234567 → "010-123-4567". 형식이 다르면 그대로 돌려준다.
String formatPhone(String digits) {
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  return digits;
}

/// 45 → "45분", 60 → "1시간", 90 → "1시간 30분"
String formatDuration(int minutes) {
  final hours = minutes ~/ 60; // ~/ 는 정수 나눗셈(몫)
  final rest = minutes % 60;
  if (hours == 0) return '$rest분';
  if (rest == 0) return '$hours시간';
  return '$hours시간 $rest분';
}
