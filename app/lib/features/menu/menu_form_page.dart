import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_message.dart';
import 'menu.dart';
import 'menu_repository.dart';

/// 메뉴 등록/수정 폼. [menu]가 null이면 새로 등록, 있으면 그 메뉴를 수정한다.
/// 저장에 성공하면 true를 결과로 돌려주며 닫힌다. (목록 화면이 그걸 보고 새로고침한다)
class MenuFormPage extends StatefulWidget {
  const MenuFormPage({
    super.key,
    required this.repository,
    required this.suggestedOrder,
    this.menu,
  });

  final MenuRepository repository;
  final Menu? menu;

  /// 새 메뉴일 때 "표시 순서"에 미리 채워 둘 값
  final int suggestedOrder;

  @override
  State<MenuFormPage> createState() => _MenuFormPageState();
}

class _MenuFormPageState extends State<MenuFormPage> {
  // Form의 상태를 꺼내 쓰기 위한 열쇠. validate()로 모든 칸을 한 번에 검사한다.
  final _formKey = GlobalKey<FormState>();

  // 입력 칸의 현재 글자를 들고 있는 객체
  late final _name = TextEditingController(text: widget.menu?.name);
  late final _price = TextEditingController(text: widget.menu?.price.toString());
  late final _duration = TextEditingController(
    text: (widget.menu?.durationMinutes ?? 60).toString(),
  );
  late final _order = TextEditingController(
    text: (widget.menu?.displayOrder ?? widget.suggestedOrder).toString(),
  );
  late MenuCategory _category = widget.menu?.category ?? MenuCategory.cut;

  bool _saving = false;

  bool get _isEdit => widget.menu != null;

  @override
  void dispose() {
    // 컨트롤러는 쓰고 나면 직접 정리해야 한다. (메모리 누수 방지)
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 검사에 걸리면 각 칸 아래에 빨간 안내가 나오고 여기서 멈춘다.
    if (!_formKey.currentState!.validate()) return;

    final input = MenuInput(
      name: _name.text.trim(),
      category: _category,
      price: int.parse(_price.text),
      durationMinutes: int.parse(_duration.text),
      displayOrder: int.parse(_order.text),
    );

    setState(() => _saving = true); // 저장 중에는 버튼을 막아 두 번 눌림을 방지한다.
    try {
      if (_isEdit) {
        await widget.repository.update(widget.menu!.id, input);
      } else {
        await widget.repository.create(input);
      }
      if (!mounted) return; // 기다리는 동안 화면이 닫혔으면 아무것도 하지 않는다.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '메뉴 수정' : '메뉴 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '메뉴 이름'),
              maxLength: 50,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '메뉴 이름을 입력해 주세요' : null,
            ),
            DropdownButtonFormField<MenuCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: [
                for (final c in MenuCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
            _NumberField(
              controller: _price,
              label: '가격 (원)',
              validator: (n) => n < 0 ? '0원 이상이어야 해요' : null,
            ),
            _NumberField(
              controller: _duration,
              label: '소요 시간 (분)',
              validator: (n) => (n < 1 || n > 720) ? '1분에서 720분 사이로 입력해 주세요' : null,
            ),
            _NumberField(
              controller: _order,
              label: '표시 순서 (작을수록 위)',
              validator: (n) => n < 0 ? '0 이상이어야 해요' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save, // null이면 버튼이 비활성화된다
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자만 입력받는 칸. 비어 있으면 안내하고, 숫자면 [validator]로 범위를 검사한다.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(int value) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 숫자 외 글자는 입력 자체를 막는다
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null) return '숫자를 입력해 주세요';
        return validator(number);
      },
    );
  }
}
