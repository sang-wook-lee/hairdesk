import '../sales/sale.dart';

// 통계 화면에 쓰는 계산 함수들. 화면(위젯)과 서버 호출에서 완전히 떨어진 순수 계산이라
// 숫자만 넣어 보면 결과를 바로 테스트할 수 있다.

/// 건당 평균 매출(원). 건수가 0이면 평균이 없으므로 null이다.
///
/// 0원이라고 돌려주면 "건당 0원"으로 오해하게 되므로, 값이 없다는 것을 null로 구분한다.
/// 화면은 null이면 "-"를 보여준다.
int? averagePerSale(int totalAmount, int count) {
  if (count == 0) return null;
  return (totalAmount / count).round();
}

/// 이전 기간과 비교한 매출 변화. 아래 두 종류 중 하나다.
/// sealed: 이 두 클래스 말고는 하위 클래스를 만들 수 없어서, 화면이 switch로 모든 경우를 빠짐없이 처리하도록 컴파일러가 확인해 준다.
sealed class SalesChange {
  const SalesChange();
}

/// 이전 기간 매출이 0원이라 비율을 만들 수 없다. (0으로 나누면 "+∞%"가 되고, "+100%"로 쓰는 것도 거짓이다)
/// 이전 기간과 이번 기간이 모두 0원인 경우도 포함한다. 화면은 "비교할 매출 없음" 정도로 보여준다.
final class NoComparison extends SalesChange {
  const NoComparison();

  @override
  bool operator ==(Object other) => other is NoComparison;

  @override
  int get hashCode => 0;
}

/// 이전 기간 대비 증감률. [percent]는 부호가 있는 정수(반올림): +12 = 12% 증가, -5 = 5% 감소, 0 = 변동 없음.
final class Changed extends SalesChange {
  const Changed(this.percent);

  final int percent;

  @override
  bool operator ==(Object other) => other is Changed && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;

  @override
  String toString() => 'Changed($percent%)';
}

/// [current]를 [previous]와 비교한다.
SalesChange compareSales(int current, int previous) {
  if (previous == 0) return const NoComparison();
  return Changed(((current - previous) * 100 / previous).round());
}

/// 결제수단 하나의 비중. [percent]는 정수 %.
class MethodShare {
  const MethodShare({
    required this.method,
    required this.totalAmount,
    required this.count,
    required this.percent,
  });

  final PaymentMethod method;
  final int totalAmount;
  final int count;
  final int percent;
}

/// 결제수단별 매출 비중. 금액이 큰 순으로 돌려주고, 비율(정수 %)의 합은 항상 정확히 100이다.
///
/// 각 비율을 따로 반올림하면 33.3 + 33.3 + 33.3 처럼 합이 99나 101이 될 수 있다.
/// 그래서 "최대 잔여법"을 쓴다:
///   1) 각 비율의 정수 부분(내림)을 먼저 정하고,
///   2) 모자라는 몫(100 − 정수 부분의 합)을 소수점 아래가 큰 항목부터 1씩 나눠 준다.
/// 계산은 소수(double) 오차를 피하려고 정수만 쓴다: 비율 = 금액 × 100 ÷ 합계.
List<MethodShare> paymentMethodShares(List<MethodTotal> totals) {
  final sum = totals.fold<int>(0, (acc, t) => acc + t.totalAmount);
  if (sum == 0) return const []; // 매출이 없으면 보여줄 비중도 없다

  final floors = [for (final t in totals) t.totalAmount * 100 ~/ sum];
  final remainders = [for (final t in totals) t.totalAmount * 100 % sum]; // 소수점 아래 크기(합계로 나누기 전 값)

  // 나눠 줄 몫: 정수 부분만으로는 100에 모자란 만큼
  var extra = 100 - floors.fold<int>(0, (acc, f) => acc + f);

  // 소수점 아래가 큰 순서(같으면 금액이 큰 쪽, 그래도 같으면 원래 순서)로 번호를 줄 세운다.
  // 마지막 기준(번호)을 넣는 이유: Dart의 List.sort는 같은 값끼리의 순서를 보장하지 않아서,
  // 금액이 같은 결제수단이 있으면 실행할 때마다 결과가 달라질 수 있기 때문이다.
  final order = List<int>.generate(totals.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      if (byRemainder != 0) return byRemainder;
      final byAmount = totals[b].totalAmount.compareTo(totals[a].totalAmount);
      return byAmount != 0 ? byAmount : a.compareTo(b);
    });
  for (final i in order) {
    if (extra == 0) break;
    floors[i] += 1;
    extra -= 1;
  }

  // 화면에는 금액이 큰 순으로 보여준다. (같으면 원래 순서)
  final display = List<int>.generate(totals.length, (i) => i)
    ..sort((a, b) {
      final byAmount = totals[b].totalAmount.compareTo(totals[a].totalAmount);
      return byAmount != 0 ? byAmount : a.compareTo(b);
    });
  return [
    for (final i in display)
      MethodShare(
        method: totals[i].method,
        totalAmount: totals[i].totalAmount,
        count: totals[i].count,
        percent: floors[i],
      ),
  ];
}
