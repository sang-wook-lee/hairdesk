package com.salonapp.stats.dto;

import com.salonapp.reservation.domain.ReservationStatus;

/** 예약 상태별 건수 한 줄. 집계 쿼리 결과를 담는다. */
public record StatusCount(ReservationStatus status, long count) {
}
