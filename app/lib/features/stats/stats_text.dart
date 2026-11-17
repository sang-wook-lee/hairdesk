import 'stats_calculations.dart';

/// 매출 변화를 화면에 보일 글자로: "+12%", "-5%", "변동 없음", "비교할 매출 없음".
///
/// switch 표현식은 SalesChange의 모든 경우를 다뤄야 컴파일된다.
/// 나중에 SalesChange에 종류가 추가되면 이 함수가 컴파일 에러로 알려 준다.
String changeText(SalesChange change) => switch (change) {
      NoComparison() => '비교할 매출 없음',
      Changed(percent: 0) => '변동 없음',
      Changed(:final percent) when percent > 0 => '+$percent%',
      Changed(:final percent) => '$percent%', // 음수는 숫자 자체에 '-'가 붙어 있다
    };
