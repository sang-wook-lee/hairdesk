import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../sales/sale.dart';
import '../stats_calculations.dart';

/// 결제수단별 색. 앱 테마 색에서 가져와서 다크 모드에도 자연스럽게 따라간다.
Color paymentColor(PaymentMethod method, ColorScheme scheme) => switch (method) {
      PaymentMethod.card => scheme.primary,
      PaymentMethod.cash => scheme.tertiary,
      PaymentMethod.transfer => scheme.secondary,
      PaymentMethod.etc => scheme.outline,
    };

/// 결제수단 비중: 가로로 이어 붙인 막대 한 줄 + 수단별 범례.
///
/// - 막대의 칸 너비는 퍼센트가 아니라 "금액"으로 나눈다. 반올림 오차 없이 실제 비율대로 그려진다. (ADR 0008)
/// - 글자로 보이는 퍼센트는 합이 100이 되도록 맞춘 값(MethodShare.percent, ADR 0007)이다.
class PaymentMethodBar extends StatelessWidget {
  const PaymentMethodBar({super.key, required this.shares});

  /// 금액이 큰 순서로 정렬된 비중 (paymentMethodShares의 결과)
  final List<MethodShare> shares;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (shares.isEmpty) {
      return Text('결제 내역이 없어요', style: text.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              // stretch: 칸이 Row의 높이(14)를 꽉 채우게 한다. 기본값(center)에서는 내용이 없는 ColoredBox의 높이가 0이 되어 막대가 안 보인다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // flex = 금액. 금액이 0원인 칸은 만들지 않는다 (flex 0은 의도와 다르게 동작할 수 있다)
                for (final s in shares)
                  if (s.totalAmount > 0)
                    Expanded(
                      flex: s.totalAmount,
                      child: ColoredBox(
                        key: ValueKey('segment-${s.method.apiValue}'),
                        color: paymentColor(s.method, scheme),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final s in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: paymentColor(s.method, scheme), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.method.label)),
                Text('${s.percent}%', style: text.titleSmall),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Text(
                    '${formatWon(s.totalAmount)} · ${s.count}건',
                    textAlign: TextAlign.right,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
