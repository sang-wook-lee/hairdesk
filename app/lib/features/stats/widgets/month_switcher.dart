import 'package:flutter/material.dart';

import '../stats_month.dart';

/// 보는 달을 바꾸는 줄: ◀ 2026년 10월 ▶ [이번 달]
///
/// 이 위젯은 "어느 달인지"를 스스로 바꾸지 않는다. 버튼을 누르면 콜백으로 알리기만 하고,
/// 실제로 달을 바꾸는 것은 부른 쪽(통계 페이지)이다. (그래서 상태가 한 곳에만 있다)
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.canGoNext,
    required this.isCurrent,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final StatsMonth month;

  /// false면 다음 달 버튼이 비활성화된다. (아직 오지 않은 달로는 못 간다. StatsMonth.canGoNext)
  final bool canGoNext;

  /// 지금 보는 달이 이번 달인가. 이번 달이면 "이번 달" 버튼이 필요 없다.
  final bool isCurrent;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(tooltip: '이전 달', icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
        Expanded(
          child: Center(
            child: Text(month.label, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        // onPressed가 null이면 버튼이 회색으로 비활성화된다
        IconButton(tooltip: '다음 달', icon: const Icon(Icons.chevron_right), onPressed: canGoNext ? onNext : null),
        // 자리를 고정해 두면 "이번 달" 버튼이 생기고 사라져도 제목 위치가 흔들리지 않는다.
        SizedBox(
          width: 84,
          child: isCurrent
              ? null
              : OutlinedButton(
                  onPressed: onToday,
                  // 기본 좌우 여백(24)이면 84 폭 안에서 글자가 두 줄로 꺾인다. 여백을 줄이고 줄바꿈도 막는다.
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('이번 달', softWrap: false),
                ),
        ),
      ],
    );
  }
}
