import 'package:flutter/material.dart';

/// 통계 화면의 각 구역(요약, 일별 매출, 결제수단 ...)이 공통으로 쓰는 카드 틀.
/// 제목 한 줄과 내용을 같은 여백으로 감싸서, 구역이 늘어도 모양이 통일되게 한다.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;

  /// 제목 오른쪽에 붙는 보조 글자나 버튼 (선택)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing, // null이면 목록에 넣지 않는다 (Dart 3.8의 null-aware 요소)
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
