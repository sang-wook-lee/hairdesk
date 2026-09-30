package com.salonapp.reservation.domain;

/** 예약 상태. 자리를 차지하는 상태는 BOOKED, COMPLETED (ADR 0003) */
public enum ReservationStatus {
    BOOKED,     // 예약됨
    COMPLETED,  // 시술 완료
    CANCELLED,  // 취소
    NO_SHOW     // 노쇼
}
