package com.salonapp.stats.dto;

import com.salonapp.reservation.domain.ReservationStatus;

import java.util.List;

/**
 * 기간 내 예약 통계.
 * noShowRate = 노쇼 / (완료 + 노쇼), 0.0 ~ 1.0. 0.25면 25%.
 * 아직 예정(BOOKED)이거나 미리 취소한 예약은 "결과가 난 예약"이 아니라서 분모에서 뺀다. (ADR 0005)
 * 분모가 0이면(결과가 난 예약이 없으면) 0.0.
 */
public record ReservationStats(
        long booked,
        long completed,
        long cancelled,
        long noShow,
        double noShowRate
) {
    public static ReservationStats from(List<StatusCount> counts) {
        long booked = countOf(counts, ReservationStatus.BOOKED);
        long completed = countOf(counts, ReservationStatus.COMPLETED);
        long cancelled = countOf(counts, ReservationStatus.CANCELLED);
        long noShow = countOf(counts, ReservationStatus.NO_SHOW);

        long decided = completed + noShow;
        double rate = decided == 0 ? 0.0 : (double) noShow / decided;
        return new ReservationStats(booked, completed, cancelled, noShow, rate);
    }

    /** DB는 건수가 0인 상태의 행은 주지 않는다. 없으면 0건이다. */
    private static long countOf(List<StatusCount> counts, ReservationStatus status) {
        return counts.stream()
                .filter(c -> c.status() == status)
                .mapToLong(StatusCount::count)
                .findFirst()
                .orElse(0L);
    }
}
