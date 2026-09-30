package com.salonapp.reservation.dto;

import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;

import java.time.OffsetDateTime;
import java.time.ZoneId;

public record ReservationResponse(
        Long id,
        Long customerId,
        String customerName,
        String customerPhone,
        Long menuId,
        String menuName,
        OffsetDateTime startAt,   // +09:00 (Asia/Seoul)로 내려준다
        OffsetDateTime endAt,
        ReservationStatus status,
        String memo
) {
    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    public static ReservationResponse from(Reservation r) {
        return new ReservationResponse(
                r.getId(),
                r.getCustomer().getId(),
                r.getCustomer().getName(),
                r.getCustomer().getPhone(),
                r.getMenu().getId(),
                r.getMenu().getName(),
                r.getStartAt().atZone(SEOUL).toOffsetDateTime(),
                r.getEndAt().atZone(SEOUL).toOffsetDateTime(),
                r.getStatus(),
                r.getMemo()
        );
    }
}
