import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/kst.dart';
import '../stats.dart';

// ---- 차트 계산 (화면과 분리한 순수 함수. 설계 이유는 ADR 0008) ----

/// 막대 높이 비율 0.0~1.0 = 그날 금액 ÷ 그 달 최고 금액. 최고 금액이 0이면(매출이 하나도 없으면) 0.
double barFraction(int amount, int max) => max == 0 ? 0 : amount / max;

/// 아래 날짜 눈금을 붙일 날인가: 1일, 5의 배수, 마지막 날.
/// 막대가 31개라 폭이 좁으므로 전부 붙이면 글자가 겹친다.
/// 마지막 날 가까이의 5의 배수(예: 31일 달의 30일)는 마지막 날 눈금과 붙어 버려서 뺀다.
bool showAxisLabel(int day, int lastDay) {
  if (day == 1 || day == lastDay) return true;
  return day % 5 == 0 && lastDay - day >= 3;
}

/// 터치한 가로 위치(dx, 0~width)가 몇 번째 막대인지. 영역 밖으로 밀려도 양 끝 막대로 맞춘다.
int chartIndexAt(double dx, double width, int count) {
  final index = (dx / width * count).floor();
  return index.clamp(0, count - 1);
}

/// 일별 매출 막대 그래프. 그래프 영역을 누르거나 좌우로 밀면 그날의 금액을 위에 보여준다.
///
/// - 막대 높이는 그 달 최고 금액을 100%로 한 비율이다.
/// - [today]를 주면 그 이후 날짜(이번 달의 남은 날)는 막대를 그리지 않고 터치도 받지 않는다.
/// - 터치는 막대 하나하나가 아니라 영역 전체에서 받아 x 위치로 막대를 고른다. 폭이 10px 남짓한 막대를 손가락으로 누르기 어려워서다.
class DailySalesChart extends StatefulWidget {
  const DailySalesChart({super.key, required this.days, this.today});

  /// 그 달의 모든 날짜(매출 없는 날 포함), 날짜순
  final List<DailySales> days;

  /// 서울 기준 오늘(시각 없는 날짜). 생략하면 모든 날짜를 그린다.
  final DateTime? today;

  @override
  State<DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<DailySalesChart> {
  static const double _chartHeight = 140;

  int? _selected; // 눌러서 고른 막대 번호. null이면 아무것도 안 골랐다.

  @override
  void didUpdateWidget(DailySalesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 달의 데이터로 바뀌었는데 이전 달의 선택이 남아 있으면 엉뚱한 날이 선택되어 보인다.
    if (!identical(oldWidget.days, widget.days)) _selected = null;
  }

  bool _isFuture(DailySales day) => widget.today != null && day.date.isAfter(widget.today!);

  void _select(double dx, double width) {
    final index = chartIndexAt(dx, width, widget.days.length);
    if (_isFuture(widget.days[index])) return; // 아직 오지 않은 날은 고를 수 없다
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final max = days.fold<int>(0, (m, d) => d.totalAmount > m ? d.totalAmount : m);
    final text = Theme.of(context).textTheme;

    if (max == 0) {
      return SizedBox(
        height: _chartHeight,
        child: Center(child: Text('이 달은 매출이 없어요', style: text.bodyMedium)),
      );
    }

    final lastDay = days.last.date.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 높이를 44로 "고정"하지 않고 "최소 44"로 둔다. 글자가 두 줄로 꺾이거나 사용자가 기기 글자 크기를 키워도 잘리지 않고 늘어난다.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: _DetailText(day: _detailDay(days, max), isBest: _selected == null),
        ),
        SizedBox(
          height: _chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                key: const ValueKey('daily-chart-area'),
                behavior: HitTestBehavior.opaque, // 막대가 없는 빈 곳을 눌러도 반응하게
                onTapDown: (d) => _select(d.localPosition.dx, width),
                onHorizontalDragUpdate: (d) => _select(d.localPosition.dx, width),
                child: Stack(
                  children: [
                    // 바닥선: 매출이 0원인 날도 "있었던 날"로 보이도록 전체에 얇은 선을 깐다
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < days.length; i++)
                          Expanded(child: _Bar(day: days[i], max: max, selected: i == _selected, future: _isFuture(days[i]))),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // 날짜 눈금. 칸 폭보다 글자가 넓을 수 있어서 OverflowBox로 옆 칸까지 번지게 한다.
        SizedBox(
          height: 16,
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: showAxisLabel(d.date.day, lastDay)
                      ? OverflowBox(
                          maxWidth: 30,
                          child: Text('${d.date.day}', style: text.labelSmall, textAlign: TextAlign.center),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 위에 보여줄 날: 고른 날이 있으면 그날, 없으면 가장 많이 번 날
  DailySales _detailDay(List<DailySales> days, int max) {
    if (_selected != null) return days[_selected!];
    return days.firstWhere((d) => d.totalAmount == max);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.max, required this.selected, required this.future});

  final DailySales day;
  final int max;
  final bool selected;
  final bool future;

  @override
  Widget build(BuildContext context) {
    if (future) return const SizedBox.shrink(); // 오지 않은 날: 막대도 바닥선 위의 표시도 없다

    final primary = Theme.of(context).colorScheme.primary;
    var fraction = barFraction(day.totalAmount, max);
    // 아주 작은 금액도 눈에 보이게 최소 높이를 준다. (0원은 그대로 0)
    if (day.totalAmount > 0 && fraction < 0.03) fraction = 0.03;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: fraction, // 막대 높이 = 영역 높이 × 비율
          widthFactor: 1,
          child: DecoratedBox(
            key: ValueKey('bar-${formatIsoDate(day.date)}'),
            decoration: BoxDecoration(
              color: selected ? primary : primary.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 그래프 위의 설명 줄. 고른 날이 없으면 "최고 매출일"을 안내해서 처음부터 읽을 거리가 있게 한다.
class _DetailText extends StatelessWidget {
  const _DetailText({required this.day, required this.isBest});

  final DailySales day;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // 내용 높이만큼만 (바깥에서 최소 높이를 준다)
      children: [
        Text(
          '${isBest ? '최고 매출일 · ' : ''}${formatKoreanDate(day.date)}',
          style: text.bodySmall,
        ),
        Text('${formatWon(day.totalAmount)} · ${day.count}건', style: text.titleMedium),
      ],
    );
  }
}
