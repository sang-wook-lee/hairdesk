import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/kst.dart';
import '../customer/customer_repository.dart';
import '../menu/menu_repository.dart';
import '../sales/sale_repository.dart';
import 'reservation.dart';
import 'reservation_form_page.dart';
import 'reservation_repository.dart';
import 'reservation_sheet.dart';
import 'reservation_tile.dart';

/// 하루 일정 화면. 날짜를 넘기며 그날의 예약을 시간순으로 본다.
class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.repository,
    required this.customerRepository,
    required this.menuRepository,
    required this.saleRepository,
    this.initialDate,
  });

  final ReservationRepository repository;

  /// 예약 추가 폼이 고객 검색과 메뉴 목록에 쓴다.
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;

  /// 예약 상세 시트의 "결제하기"가 쓴다.
  final SaleRepository saleRepository;

  /// 처음 보여줄 날짜. 생략하면 오늘(서울 기준). 테스트에서 날짜를 고정하려고 열어 둔다.
  final DateTime? initialDate;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _date = widget.initialDate ?? kstToday();
  late Future<List<Reservation>> _reservations;

  @override
  void initState() {
    super.initState();
    _reservations = _load();
  }

  Future<List<Reservation>> _load() =>
      widget.repository.fetchBetween(_date, _date); // 하루 = from과 to가 같다

  void _reload() {
    setState(() {
      _reservations = _load();
    });
  }

  void _moveTo(DateTime date) {
    _date = DateTime(date.year, date.month, date.day);
    _reload();
  }

  /// 예약 추가 화면을 열고, 예약이 만들어져 돌아오면 그 예약의 날짜로 이동한다.
  /// (다른 날짜에 예약을 잡고 돌아왔을 때 "어디 갔지?" 하지 않도록)
  Future<void> _addReservation() async {
    final created = await Navigator.of(context).push<Reservation>(
      MaterialPageRoute(
        builder: (_) => ReservationFormPage(
          reservationRepository: widget.repository,
          customerRepository: widget.customerRepository,
          menuRepository: widget.menuRepository,
          initialDate: _date,
        ),
      ),
    );
    if (created != null) {
      final day = toKst(created.startAt);
      _moveTo(DateTime(day.year, day.month, day.day));
    }
  }

  /// 예약 상세 시트를 열고, 동작이 성공해서 메시지를 들고 돌아오면 목록을 새로고침하고 알려 준다.
  Future<void> _openDetail(Reservation reservation) async {
    final message = await ReservationSheet.show(
      context,
      reservation: reservation,
      reservationRepository: widget.repository,
      saleRepository: widget.saleRepository,
      menuRepository: widget.menuRepository,
    );
    if (message == null) return; // 그냥 닫음: 바뀐 게 없다
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _moveTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
            date: _date,
            onPrevious: () => _moveTo(_date.subtract(const Duration(days: 1))),
            onNext: () => _moveTo(_date.add(const Duration(days: 1))),
            onToday: () => _moveTo(kstToday()),
            onPick: _pickDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Reservation>>(
              future: _reservations,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: errorMessage(snapshot.error!),
                    onRetry: _reload,
                  );
                }
                final reservations = snapshot.data!;
                if (reservations.isEmpty) {
                  return const Center(child: Text('이 날은 예약이 없어요.'));
                }
                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) => ReservationTile(
                    reservation: reservations[index],
                    onTap: () => _openDetail(reservations[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReservation,
        icon: const Icon(Icons.add),
        label: const Text('예약 추가'),
      ),
    );
  }
}

/// 날짜 이동 줄: ◀ 2026년 10월 23일 (금) ▶ [오늘]
class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '전날',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: TextButton(
              onPressed: onPick, // 날짜 글자를 누르면 달력이 열린다
              child: Text(
                formatKoreanDate(date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: '다음날',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          OutlinedButton(onPressed: onToday, child: const Text('오늘')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
