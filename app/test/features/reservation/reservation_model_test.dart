import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/reservation/reservation.dart';

void main() {
  test('서버 응답 JSON을 Reservation으로 바꾼다 (메모가 null이어도 된다)', () {
    final reservation = Reservation.fromJson({
      'id': 1,
      'customerId': 2,
      'customerName': '김민지',
      'customerPhone': '01012345678',
      'menuId': 1,
      'menuName': '커트',
      'startAt': '2026-10-01T14:00:00+09:00',
      'endAt': '2026-10-01T15:00:00+09:00',
      'status': 'NO_SHOW',
      'memo': null,
    });

    expect(reservation.customerName, '김민지');
    expect(reservation.status, ReservationStatus.noShow);
    expect(reservation.memo, isNull);
    // 14:00(+09:00)은 UTC 05:00 — 같은 순간이다.
    expect(reservation.startAt, DateTime.utc(2026, 10, 1, 5));
    expect(reservation.endAt.difference(reservation.startAt), const Duration(hours: 1));
  });
}
