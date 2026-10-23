import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/format.dart';
import 'customer.dart';
import 'customer_repository.dart';

/// 고객을 검색해서 고르는 화면. 고르면 그 [Customer]를 결과로 돌려주며 닫힌다.
/// 처음 온 손님이면 아래 버튼으로 바로 새 고객을 등록하고 선택까지 한 번에 끝낸다.
class CustomerPickerPage extends StatefulWidget {
  const CustomerPickerPage({super.key, required this.repository});

  final CustomerRepository repository;

  @override
  State<CustomerPickerPage> createState() => _CustomerPickerPageState();
}

class _CustomerPickerPageState extends State<CustomerPickerPage> {
  Timer? _debounce;
  late Future<List<Customer>> _results = widget.repository.search('');

  @override
  void dispose() {
    _debounce?.cancel(); // 화면이 닫힌 뒤에 타이머가 터지지 않게 정리한다
    super.dispose();
  }

  /// 글자를 입력할 때마다 서버를 부르지 않도록, 입력이 0.3초 멈추면 그때 검색한다. (디바운스)
  void _onChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _results = widget.repository.search(keyword);
      });
    });
  }

  Future<void> _registerNew() async {
    final created = await showDialog<Customer>(
      context: context,
      builder: (_) => _NewCustomerDialog(repository: widget.repository),
    );
    // 등록에 성공했으면 그 고객을 바로 선택한 것으로 보고 닫는다.
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객 선택')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '이름 또는 전화번호 뒷자리',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(errorMessage(snapshot.error!)));
                }
                final customers = snapshot.data!;
                if (customers.isEmpty) {
                  return const Center(child: Text('찾는 고객이 없어요.'));
                }
                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        c.memo == null
                            ? formatPhone(c.phone)
                            : '${formatPhone(c.phone)} · ${c.memo}',
                      ),
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registerNew,
        icon: const Icon(Icons.person_add),
        label: const Text('새 고객 등록'),
      ),
    );
  }
}

/// 새 고객 등록 대화상자. 성공하면 등록된 [Customer]를 돌려주며 닫힌다.
class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog({required this.repository});

  final CustomerRepository repository;

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _memo = TextEditingController();

  bool _saving = false;
  String? _error; // 서버가 거절한 이유 (예: 이미 등록된 고객)

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final memo = _memo.text.trim();
      final customer = await widget.repository.create(CustomerInput(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        memo: memo.isEmpty ? null : memo,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(customer);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 고객 등록'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요' : null,
            ),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: '휴대폰 번호', hintText: '010-1234-5678'),
              keyboardType: TextInputType.phone,
              validator: (v) {
                // 하이픈이 있어도 되므로 숫자만 남겨서 본다. (서버도 같은 규칙으로 다시 검사한다)
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return RegExp(r'^01[016789]\d{7,8}$').hasMatch(digits)
                    ? null
                    : '올바른 휴대폰 번호를 입력해 주세요';
              },
            ),
            TextFormField(
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
              maxLength: 1000,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중...' : '등록'),
        ),
      ],
    );
  }
}
