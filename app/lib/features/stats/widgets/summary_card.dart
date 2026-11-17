import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../stats_calculations.dart';
import '../stats_data.dart';
import '../stats_text.dart';
import 'section_card.dart';

/// 이 달의 핵심 숫자: 총 매출, 결제 건수, 건당 평균, 비교 기간 대비 증감.
class StatsSummaryCard extends StatelessWidget {
  const StatsSummaryCard({super.key, required this.data});

  final StatsData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: '총 매출',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FittedBox: 금액이 아주 커져도 줄바꿈 없이 글자를 줄여서 한 줄에 맞춘다
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatWon(data.summary.totalAmount), style: text.headlineMedium),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChangeBadge(change: data.change),
              const SizedBox(width: 8),
              Flexible(child: Text(data.comparisonLabel, style: text.bodySmall)),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(child: _Stat(label: '결제 건수', value: '${data.summary.count}건')),
              Expanded(
                child: _Stat(
                  label: '건당 평균',
                  // 건수가 0이면 평균이 없다(null). 0원이라고 쓰면 오해하므로 "-"로 보여준다. (ADR 0007)
                  value: data.averageAmount == null ? '-' : formatWon(data.averageAmount!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: text.titleMedium),
      ],
    );
  }
}

/// 증감 표시: 증가는 ▲ 초록, 감소는 ▼ 빨강, 변동 없음/비교 불가는 회색 글자만.
class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.change});

  final SalesChange change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData? icon, Color color) = switch (change) {
      Changed(percent: > 0) => (Icons.arrow_upward, Colors.green.shade700),
      Changed(percent: < 0) => (Icons.arrow_downward, scheme.error),
      _ => (null, scheme.onSurfaceVariant), // 변동 없음(0%)과 비교 불가
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 16, color: color),
        Text(
          changeText(change),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
