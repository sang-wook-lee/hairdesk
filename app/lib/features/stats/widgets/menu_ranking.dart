import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../stats.dart';

/// 메뉴별 매출 순위. 위에서부터 매출이 큰 순서이고, [limit]개까지만 보여준 뒤 나머지는 "그 외"로 묶는다.
///
/// 각 줄의 얇은 막대는 1위를 100%로 한 상대 크기다. 1위와 얼마나 차이 나는지가 숫자를 읽지 않아도 보인다.
class MenuRanking extends StatelessWidget {
  const MenuRanking({super.key, required this.menus, this.limit = 5});

  /// 서버가 준 순서(총액이 큰 순) 그대로
  final List<MenuSales> menus;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (menus.isEmpty) {
      return Text('이 달에 팔린 메뉴가 없어요', style: text.bodyMedium);
    }

    final shown = menus.take(limit).toList();
    final rest = menus.skip(limit).toList();
    final top = menus.first.totalAmount; // 1위 금액: 막대 길이의 기준

    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, child: Text('${i + 1}', style: text.titleSmall)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(shown[i].menuName, style: text.bodyLarge)),
                          Text(formatWon(shown[i].totalAmount), style: text.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: top == 0 ? 0 : shown[i].totalAmount / top,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 44,
                            child: Text('${shown[i].count}건', textAlign: TextAlign.right, style: text.bodySmall),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (rest.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: Text('그 외 ${rest.length}개 메뉴', style: text.bodySmall)),
                Text(
                  '${formatWon(rest.fold<int>(0, (sum, m) => sum + m.totalAmount))} · '
                  '${rest.fold<int>(0, (sum, m) => sum + m.count)}건',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
