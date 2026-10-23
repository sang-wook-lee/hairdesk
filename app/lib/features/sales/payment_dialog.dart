import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import 'sale.dart';

/// 결제 입력 대화상자. 확인하면 [PaymentInput]을 돌려주며 닫히고, 취소하면 null.
/// 이 대화상자는 서버를 부르지 않는다. 입력만 받고, 실제 등록은 부른 쪽(예약 시트)이 한다.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.title,
    required this.price,
  });

  /// 어떤 결제인지 보여줄 글 (예: "김민지 · 커트")
  final String title;

  /// 메뉴 정가. 금액 칸의 기본값이 된다. 알 수 없으면 null이고 직접 입력한다.
  final int? price;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.price?.toString());
  final _memo = TextEditingController();
  PaymentMethod _method = PaymentMethod.card;

  @override
  void initState() {
    super.initState();
    // 금액을 고칠 때마다 아래 "할인" 안내가 바로 바뀌도록 화면을 다시 그린다.
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final memo = _memo.text.trim();
    Navigator.of(context).pop(PaymentInput(
      amount: int.parse(_amount.text),
      method: _method,
      memo: memo.isEmpty ? null : memo,
    ));
  }

  /// "정가 20,000원 · 할인 2,000원" 같은 안내. 정가를 모르면 null.
  String? get _priceHint {
    final price = widget.price;
    if (price == null) return null;
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount == price) return '정가 ${formatWon(price)}';
    if (amount < price) return '정가 ${formatWon(price)} · 할인 ${formatWon(price - amount)}';
    return '정가 ${formatWon(price)} · 정가보다 ${formatWon(amount - price)} 더 받음';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('결제'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              // ChoiceChip: 여러 개 중 하나를 고르는 알약 버튼. 결제 수단 4개를 한 줄에 보여준다.
              Wrap(
                spacing: 8,
                children: [
                  for (final m in PaymentMethod.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              TextFormField(
                controller: _amount,
                decoration: InputDecoration(labelText: '받은 금액 (원)', helperText: _priceHint),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // 0원도 허용한다: 서비스로 해 준 경우에도 "결제 = 완료 처리"를 해야 하기 때문.
                validator: (v) => int.tryParse(v ?? '') == null ? '금액을 입력해 주세요 (0원도 가능)' : null,
              ),
              TextFormField(
                controller: _memo,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
                maxLength: 500,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
        FilledButton(onPressed: _submit, child: const Text('결제 등록')),
      ],
    );
  }
}
