import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import 'staff.dart';
import 'staff_repository.dart';

/// 직원 등록/수정 폼. [staff]가 null이면 새로 등록, 있으면 그 직원을 수정한다.
/// 저장에 성공하면 true를 결과로 돌려주며 닫힌다. (목록 화면이 그걸 보고 새로고침한다)
///
/// 입력은 이름과 직책 둘뿐이다. 근무 여부는 이 폼에서 바꾸지 않는다.
/// (목록의 "근무 종료/재개" 동작으로만 바꾼다. 서버도 같은 규칙이다)
class StaffFormPage extends StatefulWidget {
  const StaffFormPage({super.key, required this.repository, this.staff});

  final StaffRepository repository;
  final Staff? staff;

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  /// 직책 칸 아래의 빠른 선택 버튼. 누르면 직책 칸에 그 글자가 들어간다. (직접 써도 된다)
  static const _commonPositions = ['원장', '실장', '디자이너', '인턴'];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?.name);
  late final _position = TextEditingController(text: widget.staff?.position);

  bool _saving = false;

  bool get _isEdit => widget.staff != null;

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 앞뒤 공백은 잘라서 보낸다. (서버도 자르지만, 화면에서 보는 값과 보내는 값을 같게 둔다)
    final input = StaffInput(name: _name.text.trim(), position: _position.text.trim());

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.repository.update(widget.staff!.id, input);
      } else {
        await widget.repository.create(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  void _pickPosition(String position) {
    setState(() => _position.text = position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '직원 수정' : '직원 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                // 이름·직책이 같은 직원이 있을 수 있어서, 직원을 구별하는 번호를 보여준다. (바꿀 수 없다)
                child: Text('직원 번호 #${widget.staff!.id}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름'),
              maxLength: 30,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '이름을 입력해 주세요' : null,
            ),
            TextFormField(
              controller: _position,
              decoration: const InputDecoration(labelText: '직책', hintText: '예: 원장, 실장, 디자이너'),
              maxLength: 30,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '직책을 입력해 주세요' : null,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final position in _commonPositions)
                  ActionChip(label: Text(position), onPressed: () => _pickPosition(position)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '이름과 직책이 같은 직원도 등록할 수 있어요. 직원은 번호로 구별돼요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
