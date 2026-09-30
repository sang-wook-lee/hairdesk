package com.salonapp.reservation.dto;

import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;

/** 예약 시간 변경 요청. 새 시작 시각만 받는다. */
public record RescheduleRequest(@NotNull OffsetDateTime startAt) {
}
