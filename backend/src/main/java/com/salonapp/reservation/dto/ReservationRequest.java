package com.salonapp.reservation.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/**
 * 예약 등록 요청. startAt은 오프셋을 포함한 ISO 형식: "2026-10-01T14:00:00+09:00"
 * 종료 시각은 받지 않는다. 메뉴 소요시간으로 서버가 계산한다.
 */
public record ReservationRequest(
        @NotNull Long customerId,
        @NotNull Long menuId,
        @NotNull OffsetDateTime startAt,
        @Size(max = 500) String memo
) {
}
