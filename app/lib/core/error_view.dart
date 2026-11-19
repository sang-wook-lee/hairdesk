import 'package:flutter/material.dart';

/// 데이터를 불러오지 못했을 때 화면 가운데에 보여주는 공용 오류 화면.
///
/// 홈·일정·메뉴·통계 화면이 똑같은 모양을 각자 복사해 쓰던 것을 한 곳으로 모았다.
/// [message]는 보통 `errorMessage(error)`(core/error_message.dart)의 결과를 넘긴다.
/// [onRetry]는 "다시 시도" 버튼을 눌렀을 때 호출된다. (보통 화면의 `_reload`)
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
