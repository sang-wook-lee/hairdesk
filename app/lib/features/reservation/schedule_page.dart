import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/kst.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

/// 하루 일정 화면. 날짜를 넘기며 그날의 예약을 시간순으로 본다.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.repository, this.initialDate});

  final ReservationRepository repository;

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
                  itemBuilder: (context, index) =>
                      _ReservationTile(reservation: reservations[index]),
                );
              },
            ),
          ),
        ],
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

/// 예약 한 줄. 취소/노쇼는 흐리게 보여서 "실제로 올 사람"이 한눈에 구분된다.
class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final inactive = r.status == ReservationStatus.cancelled ||
        r.status == ReservationStatus.noShow;
    final textColor = inactive ? Theme.of(context).disabledColor : null;

    return ListTile(
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(formatHm(r.startAt),
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text(formatHm(r.endAt), style: TextStyle(color: textColor)),
        ],
      ),
      title: Text('${r.customerName} · ${r.menuName}',
          style: TextStyle(color: textColor)),
      subtitle: r.memo == null ? null : Text(r.memo!),
      trailing: _StatusChip(status: r.status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 상태마다 색을 다르게 해서 글자를 읽지 않아도 구분되게 한다.
    final color = switch (status) {
      ReservationStatus.booked => scheme.primaryContainer,
      ReservationStatus.completed => Colors.green.shade100,
      ReservationStatus.cancelled => Colors.grey.shade300,
      ReservationStatus.noShow => Colors.red.shade100,
    };
    return Chip(
      label: Text(status.label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
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
