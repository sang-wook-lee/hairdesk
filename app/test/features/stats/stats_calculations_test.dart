import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/sales/sale.dart';
import 'package:hairdesk/features/stats/stats_calculations.dart';

MethodTotal _method(PaymentMethod method, int amount, [int count = 1]) =>
    MethodTotal(method: method, totalAmount: amount, count: count);

void main() {
  group('건당 평균', () {
    test('총액을 건수로 나누고 원 단위로 반올림한다', () {
      expect(averagePerSale(1622000, 30), 54067); // 54066.67
      expect(averagePerSale(100000, 4), 25000);
      expect(averagePerSale(10, 4), 3); // 2.5 → 반올림
    });

    test('건수가 0이면 평균이 없다 (0으로 나누지 않고, 0원도 아니다)', () {
      expect(averagePerSale(0, 0), isNull);
      expect(averagePerSale(5000, 0), isNull); // 있을 수 없는 입력이지만 터지지 않는다
    });
  });

  group('이전 기간과의 비교', () {
    test('증가: 100,000 → 112,000은 +12%', () {
      expect(compareSales(112000, 100000), const Changed(12));
    });

    test('감소: 100,000 → 95,000은 -5%', () {
      expect(compareSales(95000, 100000), const Changed(-5));
    });

    test('절반이 되면 -50%, 두 배면 +100%, 세 배면 +200%', () {
      expect(compareSales(50000, 100000), const Changed(-50));
      expect(compareSales(200000, 100000), const Changed(100));
      expect(compareSales(300000, 100000), const Changed(200));
    });

    test('정수로 반올림한다: 소수점 둘째 자리에서 올림/내림', () {
      expect(compareSales(110500, 100000), const Changed(11)); // 10.5% → 11 (0.5는 올림)
      expect(compareSales(110400, 100000), const Changed(10)); // 10.4% → 10
      expect(compareSales(99600, 100000), const Changed(0)); // -0.4% → 0 (변동 없음)
    });

    test('같으면 변동 없음(0%)', () {
      expect(compareSales(100000, 100000), const Changed(0));
    });

    test('매출이 전부 사라지면 -100%', () {
      expect(compareSales(0, 100000), const Changed(-100));
    });

    test('이전 기간 매출이 0원이면 비율을 만들지 않는다 (이번 매출이 있어도, 없어도)', () {
      expect(compareSales(50000, 0), const NoComparison());
      expect(compareSales(0, 0), const NoComparison());
    });
  });

  group('결제수단 비중', () {
    test('실제 서버 값(카드 713,000 / 현금 441,000 / 이체 468,000)은 금액순 44 / 29 / 27, 합 100', () {
      final shares = paymentMethodShares([
        _method(PaymentMethod.card, 713000, 14),
        _method(PaymentMethod.cash, 441000, 9),
        _method(PaymentMethod.transfer, 468000, 7),
      ]);

      // 단순 반올림은 44 + 27 + 29 = 100 이 되지만, 이 값은 "정수 부분 43+27+28=98에서 2를 나눠 준" 결과다.
      expect(shares.map((s) => s.method), [PaymentMethod.card, PaymentMethod.transfer, PaymentMethod.cash]);
      expect(shares.map((s) => s.percent), [44, 29, 27]);
      expect(shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
      expect(shares.first.totalAmount, 713000);
      expect(shares.first.count, 14);
    });

    test('똑같이 셋으로 나누면 33 / 33 / 34가 아니라 합 100이 되도록 하나에 1을 더 준다', () {
      final shares = paymentMethodShares([
        _method(PaymentMethod.card, 10000),
        _method(PaymentMethod.cash, 10000),
        _method(PaymentMethod.transfer, 10000),
      ]);

      expect(shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
      expect(shares.map((s) => s.percent).toList()..sort(), [33, 33, 34]);
    });

    test('각각 반올림하면 합이 101이 되는 경우에도 100으로 맞춘다 (0.5씩 걸치는 값)', () {
      // 12.5% 8개: 따로 반올림하면 13 × 8 = 104가 되지만 합은 100이어야 한다.
      final shares = paymentMethodShares([
        for (var i = 0; i < 8; i++) _method(PaymentMethod.values[i % 4], 1000),
      ]);

      expect(shares.fold<int>(0, (sum, s) => sum + s.percent), 100);
      expect(shares.map((s) => s.percent).toSet(), {12, 13}); // 4개는 13, 4개는 12
    });

    test('하나뿐이면 100%', () {
      final shares = paymentMethodShares([_method(PaymentMethod.card, 18000)]);

      expect(shares.single.percent, 100);
    });

    test('아주 작은 비중도 합을 깨지 않는다: 99.9% / 0.1%는 100 / 0 (남는 1을 소수점이 큰 쪽이 가져간다)', () {
      final shares = paymentMethodShares([
        _method(PaymentMethod.card, 999000),
        _method(PaymentMethod.cash, 1000),
      ]);

      expect(shares.map((s) => s.percent), [100, 0]);
    });

    test('금액이 같으면 입력한 순서를 지키고, 몫도 앞에 있는 쪽이 먼저 받는다 (실행마다 결과가 같다)', () {
      final shares = paymentMethodShares([
        _method(PaymentMethod.card, 10000),
        _method(PaymentMethod.cash, 10000),
        _method(PaymentMethod.transfer, 10000),
      ]);

      expect(shares.map((s) => s.method), [PaymentMethod.card, PaymentMethod.cash, PaymentMethod.transfer]);
      expect(shares.map((s) => s.percent), [34, 33, 33]);
    });

    test('금액이 큰 순서로 돌려준다 (입력 순서와 무관)', () {
      final shares = paymentMethodShares([
        _method(PaymentMethod.cash, 100),
        _method(PaymentMethod.card, 300),
        _method(PaymentMethod.transfer, 200),
      ]);

      expect(shares.map((s) => s.method), [PaymentMethod.card, PaymentMethod.transfer, PaymentMethod.cash]);
    });

    test('매출이 없으면(빈 목록, 또는 전부 0원) 보여줄 비중이 없다', () {
      expect(paymentMethodShares(const []), isEmpty);
      expect(paymentMethodShares([_method(PaymentMethod.card, 0, 0)]), isEmpty);
    });
  });
}
