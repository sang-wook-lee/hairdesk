package com.salonapp.reservation.controller;

import com.salonapp.reservation.dto.RescheduleRequest;
import com.salonapp.reservation.dto.ReservationRequest;
import com.salonapp.reservation.dto.ReservationResponse;
import com.salonapp.reservation.service.ReservationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.time.LocalDate;
import java.util.List;

/**
 * 예약 API.
 *
 * POST  /api/reservations                                  등록 → 201 (시간이 겹치면 409)
 * GET   /api/reservations?from=2026-10-01&to=2026-10-07    기간 조회 (하루만 보려면 from=to)
 * GET   /api/reservations/{id}                             단건 조회
 * PATCH /api/reservations/{id}/time                        시간 변경
 * POST  /api/reservations/{id}/cancel                      취소
 * POST  /api/reservations/{id}/complete                    시술 완료
 * POST  /api/reservations/{id}/no-show                     노쇼
 *
 * 상태 변경은 "PATCH {status}" 하나로 합치지 않고 동작별 주소로 나눴다. 주소만 봐도 무슨 일인지 드러난다.
 */
@Tag(name = "예약", description = "예약 등록/조회/변경. 시간이 겹치는 예약은 불가 (ADR 0003)")
@RestController
@RequestMapping("/api/reservations")
@RequiredArgsConstructor
public class ReservationController {

    private final ReservationService reservationService;

    @Operation(summary = "예약 등록", description = "종료 시각은 메뉴 소요시간으로 자동 계산. 겹치는 예약이 있으면 409")
    @PostMapping
    public ResponseEntity<ReservationResponse> create(@Valid @RequestBody ReservationRequest request) {
        ReservationResponse created = reservationService.create(request);
        return ResponseEntity.created(URI.create("/api/reservations/" + created.id())).body(created);
    }

    @Operation(summary = "기간별 예약 조회", description = "from~to(양쪽 포함, 서울 기준 날짜)에 시작하는 예약을 시간순으로. 취소된 예약도 포함")
    @GetMapping
    public List<ReservationResponse> findBetween(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return reservationService.findBetween(from, to);
    }

    @Operation(summary = "예약 단건 조회")
    @GetMapping("/{id}")
    public ReservationResponse findById(@PathVariable Long id) {
        return reservationService.findById(id);
    }

    @Operation(summary = "예약 시간 변경", description = "예약됨 상태에서만 가능. 소요시간은 유지. 겹치면 409")
    @PatchMapping("/{id}/time")
    public ReservationResponse reschedule(@PathVariable Long id, @Valid @RequestBody RescheduleRequest request) {
        return reservationService.reschedule(id, request);
    }

    @Operation(summary = "예약 취소", description = "취소하면 그 시간에 다시 예약할 수 있다")
    @PostMapping("/{id}/cancel")
    public ReservationResponse cancel(@PathVariable Long id) {
        return reservationService.cancel(id);
    }

    @Operation(summary = "시술 완료 처리")
    @PostMapping("/{id}/complete")
    public ReservationResponse complete(@PathVariable Long id) {
        return reservationService.complete(id);
    }

    @Operation(summary = "노쇼 처리")
    @PostMapping("/{id}/no-show")
    public ReservationResponse noShow(@PathVariable Long id) {
        return reservationService.markNoShow(id);
    }
}
