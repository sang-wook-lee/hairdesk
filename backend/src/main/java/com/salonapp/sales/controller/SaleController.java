package com.salonapp.sales.controller;

import com.salonapp.sales.dto.SaleRequest;
import com.salonapp.sales.dto.SaleResponse;
import com.salonapp.sales.dto.SaleUpdateRequest;
import com.salonapp.sales.dto.SalesSummaryResponse;
import com.salonapp.sales.service.SaleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.time.LocalDate;
import java.util.List;

/**
 * 매출 API.
 *
 * POST /api/sales                                   등록 → 201 (예약 결제 또는 워크인)
 * GET  /api/sales?from=2026-10-01&to=2026-10-31     기간별 목록 (최신순)
 * GET  /api/sales/summary?from=...&to=...           기간 요약 (총액/건수/결제수단별)
 * GET  /api/sales/{id}                              단건 조회
 * PUT  /api/sales/{id}                              정정 (금액/수단/결제시각/메모)
 *
 * 삭제 API는 없다. 매출은 장부이므로 지우지 않고 정정한다. (ADR 0004)
 *
 * 주소 주의: "/summary"는 "/{id}"와 모양이 겹친다. 스프링은 더 구체적인(글자가 고정된) 쪽을 먼저 고르므로
 * "/summary"는 요약으로, "/5"는 단건 조회로 정확히 갈린다.
 */
@Tag(name = "매출", description = "결제 기록과 기간별 매출 요약 (ADR 0004)")
@RestController
@RequestMapping("/api/sales")
@RequiredArgsConstructor
public class SaleController {

    private final SaleService saleService;

    @Operation(summary = "매출 등록",
            description = "예약 결제: reservationId + paymentMethod (예약이 자동으로 완료 처리됨). "
                    + "워크인: customerId + menuId + paymentMethod. amount 생략 시 메뉴 정가. 같은 예약에 두 번 등록하면 409")
    @PostMapping
    public ResponseEntity<SaleResponse> create(@Valid @RequestBody SaleRequest request) {
        SaleResponse created = saleService.create(request);
        return ResponseEntity.created(URI.create("/api/sales/" + created.id())).body(created);
    }

    @Operation(summary = "기간별 매출 목록", description = "from~to(양쪽 포함, 서울 기준 날짜), 결제 시각 최신순")
    @GetMapping
    public List<SaleResponse> findBetween(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return saleService.findBetween(from, to);
    }

    @Operation(summary = "기간 매출 요약", description = "총 매출, 건수, 결제수단별 합계")
    @GetMapping("/summary")
    public SalesSummaryResponse summarize(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return saleService.summarize(from, to);
    }

    @Operation(summary = "매출 단건 조회")
    @GetMapping("/{id}")
    public SaleResponse findById(@PathVariable Long id) {
        return saleService.findById(id);
    }

    @Operation(summary = "매출 정정", description = "금액/결제수단/결제시각/메모만 수정. 고객·메뉴·정가는 바꿀 수 없다")
    @PutMapping("/{id}")
    public SaleResponse update(@PathVariable Long id, @Valid @RequestBody SaleUpdateRequest request) {
        return saleService.update(id, request);
    }
}
