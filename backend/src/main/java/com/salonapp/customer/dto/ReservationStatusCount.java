package com.salonapp.customer.dto;

import com.salonapp.reservation.domain.ReservationStatus;

/**
 * 한 고객의 예약 상태별 건수 한 줄. (예: 노쇼 → 1)
 * 통계 패키지의 StatusCount와 모양은 같지만, 고객 기능이 통계 코드에 기대지 않게 일부러 따로 둔다.
 */
public record ReservationStatusCount(ReservationStatus status, long count) {
}
