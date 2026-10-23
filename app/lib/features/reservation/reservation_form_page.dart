import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/kst.dart';
import '../customer/customer.dart';
import '../customer/customer_picker_page.dart';
import '../customer/customer_repository.dart';
import '../menu/menu.dart';
import '../menu/menu_repository.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

/// 예약 등록 화면. 저장에 성공하면 만들어진 [Reservation]을 결과로 돌려주며 닫힌다.
/// (일정 화면이 그 예약의 날짜로 이동해서 방금 만든 예약을 바로 보여준다)
class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({
    super.key,
    required this.reservationRepository,
    required this.customerRepository,
    required this.menuRepository,
    required this.initialDate,
  });

  final ReservationRepository reservationRepository;
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;

  /// 일정 화면에서 보고 있던 날짜. 날짜 칸의 기본값이다.
  final DateTime initialDate;

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _memo = TextEditingController();

  /// 판매 중인 메뉴만 불러온다. (판매 중지 메뉴는 서버도 예약을 거절한다)
  late final Future<List<Menu>> _menus = widget.menuRepository.fetchAll();

  Customer? _customer;
  Menu? _menu;
  late DateTime _date = widget.initialDate;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  bool _customerMissing = false; // 저장을 눌렀는데 고객이 비어 있었는가 (빨간 안내용)
  bool _saving = false;
  String? _error; // 서버가 거절한 이유. 예: "해당 시간에 이미 예약이 있습니다."

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  /// 선택한 날짜 + 시간을 "서울 벽시계 시각" 하나로 합친다.
  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => CustomerPickerPage(repository: widget.customerRepository),
      ),
    );
    if (picked != null) {
      setState(() {
        _customer = picked;
        _customerMissing = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    // 메뉴는 폼 검증, 고객은 별도 칸이라 따로 확인한다. 둘 다 안내가 나오도록 먼저 계산해 둔다.
    final formOk = _formKey.currentState!.validate();
    setState(() => _customerMissing = _customer == null);
    if (!formOk || _customer == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final memo = _memo.text.trim();
      final created = await widget.reservationRepository.create(
        customerId: _customer!.id,
        menuId: _menu!.id,
        startAt: _start,
        memo: memo.isEmpty ? null : memo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e); // 409면 서버가 만든 문장 그대로 보인다
      });
    }
  }

  /// "10:00 ~ 11:00 (1시간)". 메뉴를 고르기 전에는 종료 시각을 알 수 없다.
  String? get _preview {
    final menu = _menu;
    if (menu == null) return null;
    final end = _start.add(Duration(minutes: menu.durationMinutes));
    final nextDay = end.day != _start.day ? '다음날 ' : '';
    return '${_hm(_start)} ~ $nextDay${_hm(end)} (${formatDuration(menu.durationMinutes)})';
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('예약 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TapField(
              label: '고객',
              value: _customer == null
                  ? '탭해서 고객 선택'
                  : '${_customer!.name} · ${formatPhone(_customer!.phone)}',
              errorText: _customerMissing ? '고객을 선택해 주세요' : null,
              onTap: _pickCustomer,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Menu>>(
              future: _menus,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text(errorMessage(snapshot.error!), style: TextStyle(color: errorColor));
                }
                return DropdownButtonFormField<Menu>(
                  decoration: const InputDecoration(labelText: '시술 메뉴'),
                  hint: const Text('메뉴 선택'),
                  items: [
                    for (final m in snapshot.data!)
                      DropdownMenuItem(
                        value: m,
                        child: Text('${m.name} · ${formatDuration(m.durationMinutes)} · ${formatWon(m.price)}'),
                      ),
                  ],
                  onChanged: (m) => setState(() => _menu = m),
                  validator: (m) => m == null ? '메뉴를 선택해 주세요' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            _TapField(label: '날짜', value: formatKoreanDate(_date), onTap: _pickDate),
            const SizedBox(height: 16),
            _TapField(label: '시작 시간', value: _hm(_start), onTap: _pickTime),
            if (_preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('예상: $_preview', style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
              maxLength: 500,
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: errorColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: errorColor))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
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

/// 글자를 직접 치지 않고 탭해서 고르는 칸 (고객, 날짜, 시간).
/// InputDecorator는 입력 칸과 같은 모양(라벨, 밑줄, 에러 표시)을 입혀 주는 껍데기다.
class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Text(value),
      ),
    );
  }
}
