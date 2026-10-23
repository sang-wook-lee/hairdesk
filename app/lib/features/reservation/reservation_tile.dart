import 'package:flutter/material.dart';

import '../../core/kst.dart';
import 'reservation.dart';

/// 예약 한 줄. 취소/노쇼는 흐리게 보여서 "실제로 올 사람"이 한눈에 구분된다.
class ReservationTile extends StatelessWidget {
  const ReservationTile({super.key, required this.reservation, required this.onTap});

  final Reservation reservation;
  final VoidCallback onTap;

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
      trailing: StatusChip(status: r.status),
      onTap: onTap,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

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
