import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../stats.dart';

/// 고객 현황: 이 달에 결제한 고객 수와 신규/재방문 구성. (정의는 ADR 0005: 신규 = 기간 시작 전 결제 이력이 없는 고객)
class CustomerStatsBody extends StatelessWidget {
  const CustomerStatsBody({super.key, required this.stats});

  final CustomerStats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (stats.totalCustomers == 0) {
      return Text('이 달에 방문한 고객이 없어요', style: text.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${stats.totalCustomers}명', style: text.headlineSmall),
        const SizedBox(height: 10),
        // 신규 / 재방문을 인원 비율대로 이어 붙인 막대. 한쪽이 0명이면 그 칸은 만들지 않는다.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, // 칸이 막대 높이(12)를 꽉 채우게 (결제수단 막대와 같은 이유)
              children: [
                if (stats.newCustomers > 0)
                  Expanded(flex: stats.newCustomers, child: ColoredBox(color: scheme.tertiary)),
                if (stats.returningCustomers > 0)
                  Expanded(flex: stats.returningCustomers, child: ColoredBox(color: scheme.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Legend(color: scheme.tertiary, label: '신규', value: '${stats.newCustomers}명')),
            Expanded(child: _Legend(color: scheme.primary, label: '재방문', value: '${stats.returningCustomers}명')),
          ],
        ),
      ],
    );
  }
}

/// 예약 현황: 완료 / 예정 / 취소 / 노쇼 건수와 노쇼율.
/// 노쇼율 = 노쇼 ÷ (완료 + 노쇼). 아직 안 온 예정과 미리 취소한 예약은 분모에서 뺀다. (ADR 0005)
class ReservationStatsBody extends StatelessWidget {
  const ReservationStatsBody({super.key, required this.stats});

  final ReservationStats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Count(label: '완료', value: stats.completed)),
            Expanded(child: _Count(label: '예정', value: stats.booked)),
            Expanded(child: _Count(label: '취소', value: stats.cancelled)),
            Expanded(child: _Count(label: '노쇼', value: stats.noShow)),
          ],
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(child: Text('노쇼율', style: text.bodyMedium)),
            Text(formatPercent(stats.noShowRate), style: text.titleMedium),
          ],
        ),
        const SizedBox(height: 2),
        Text('노쇼 ÷ (완료 + 노쇼)', style: text.bodySmall),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label $value'),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 2),
        Text('$value', style: text.titleLarge),
      ],
    );
  }
}
