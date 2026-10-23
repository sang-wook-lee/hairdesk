import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/kst.dart';
import '../menu/menu_repository.dart';
import '../sales/payment_dialog.dart';
import '../sales/sale.dart';
import '../sales/sale_repository.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

/// 예약 상세 시트. 내용을 보여주고, "예약" 상태일 때 결제 / 시간 변경 / 취소 / 노쇼를 할 수 있다.
///
/// 동작이 성공하면 사용자에게 알릴 메시지(예: "결제가 등록되었어요")를 결과로 돌려주며 닫힌다.
/// 그냥 닫으면 null이다. 일정 화면은 메시지를 받았을 때만 목록을 새로고침한다.
class ReservationSheet extends StatefulWidget {
  const ReservationSheet({
    super.key,
    required this.reservation,
    required this.reservationRepository,
    required this.saleRepository,
    required this.menuRepository,
  });

  final Reservation reservation;
  final ReservationRepository reservationRepository;
  final SaleRepository saleRepository;
  final MenuRepository menuRepository;

  /// 시트를 화면 아래에서 올린다. 닫힐 때 돌려주는 메시지를 그대로 반환한다.
  static Future<String?> show(
    BuildContext context, {
    required Reservation reservation,
    required ReservationRepository reservationRepository,
    required SaleRepository saleRepository,
    required MenuRepository menuRepository,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // 내용 높이만큼 올라오게 한다
      showDragHandle: true,
      builder: (_) => ReservationSheet(
        reservation: reservation,
        reservationRepository: reservationRepository,
        saleRepository: saleRepository,
        menuRepository: menuRepository,
      ),
    );
  }

  @override
  State<ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<ReservationSheet> {
  bool _busy = false; // 서버와 통신 중이면 버튼을 막아 중복 클릭을 방지한다
  String? _error; // 서버가 거절한 이유

  Reservation get _r => widget.reservation;

  /// 서버 동작 하나를 실행한다. 성공하면 메시지를 들고 시트를 닫고, 실패하면 시트 안에 이유를 보여준다.
  /// 취소·결제·시간 변경이 모두 같은 "진행 중 표시 → 실행 → 성공/실패 처리" 흐름이라 한 곳으로 모았다.
  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await action();
      if (!mounted) return; // 기다리는 동안 시트가 닫혔으면 아무것도 하지 않는다
      Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<bool> _confirm(String title, String message, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('돌아가기')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
        ],
      ),
    );
    return result == true; // 바깥을 눌러 닫으면 null → 취소로 본다
  }

  Future<void> _cancel() async {
    final ok = await _confirm('예약 취소', '${_r.customerName}님의 예약을 취소할까요?\n취소하면 그 시간에 다시 예약을 받을 수 있어요.', '예약 취소');
    if (!ok) return;
    await _run(() async {
      await widget.reservationRepository.cancel(_r.id);
      return '예약을 취소했어요';
    });
  }

  Future<void> _noShow() async {
    final ok = await _confirm('노쇼 처리', '${_r.customerName}님을 노쇼로 처리할까요?', '노쇼 처리');
    if (!ok) return;
    await _run(() async {
      await widget.reservationRepository.markNoShow(_r.id);
      return '노쇼로 처리했어요';
    });
  }

  Future<void> _pay() async {
    // 결제창에 정가를 미리 채워 주려고 메뉴 가격을 찾는다. 못 찾아도(네트워크, 삭제 등) 직접 입력하면 되니 막지 않는다.
    setState(() => _busy = true);
    int? price;
    try {
      final menus = await widget.menuRepository.fetchAll(includeInactive: true); // 이미 판매 중지된 메뉴일 수도 있다
      price = menus.where((m) => m.id == _r.menuId).firstOrNull?.price;
    } catch (_) {
      price = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final input = await showDialog<PaymentInput>(
      context: context,
      builder: (_) => PaymentDialog(title: '${_r.customerName} · ${_r.menuName}', price: price),
    );
    if (input == null) return;

    await _run(() async {
      await widget.saleRepository.create(
        reservationId: _r.id,
        amount: input.amount,
        method: input.method,
        memo: input.memo,
      );
      return '결제가 등록되었어요 (${formatWon(input.amount)})';
    });
  }

  Future<void> _reschedule() async {
    final current = toKst(_r.startAt);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) return;

    await _run(() async {
      await widget.reservationRepository.reschedule(
        _r.id,
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
      return '예약 시간을 바꿨어요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final day = toKst(r.startAt);
    final editable = r.status == ReservationStatus.booked;
    final errorColor = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.customerName, style: Theme.of(context).textTheme.titleLarge),
                ),
                Chip(label: Text(r.status.label), visualDensity: VisualDensity.compact),
              ],
            ),
            Text(formatPhone(r.customerPhone)),
            const SizedBox(height: 12),
            Text(r.menuName),
            Text('${formatKoreanDate(day)}  ${formatHm(r.startAt)} ~ ${formatHm(r.endAt)}'),
            if (r.memo != null) ...[
              const SizedBox(height: 8),
              Text('메모: ${r.memo}'),
            ],
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: errorColor)),
              ),
            const SizedBox(height: 16),
            if (editable) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _pay,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('결제하기'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: _busy ? null : _reschedule, child: const Text('시간 변경')),
                  OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('예약 취소')),
                  OutlinedButton(onPressed: _busy ? null : _noShow, child: const Text('노쇼')),
                ],
              ),
            ] else
              Text(
                '${r.status.label} 상태의 예약은 바꿀 수 없어요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
