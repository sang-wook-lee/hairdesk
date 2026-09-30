package com.salonapp.stats.controller;

import com.salonapp.stats.dto.CustomerStats;
import com.salonapp.stats.dto.DailySales;
import com.salonapp.stats.dto.MenuSales;
import com.salonapp.stats.dto.MonthlySales;
import com.salonapp.stats.dto.ReservationStats;
import com.salonapp.stats.service.StatsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/**
 * 통계 API. 전부 조회(GET)뿐이다. 날짜는 서울 기준, from/to 양쪽 포함. 정의는 ADR 0005.
 *
 * GET /api/stats/sales/daily?from=&to=      일별 매출 (없는 날은 0, 최대 366일)
 * GET /api/stats/sales/monthly?year=2026    월별 매출 (12개월)
 * GET /api/stats/sales/by-menu?from=&to=    메뉴별 매출 (많이 번 순)
 * GET /api/stats/customers?from=&to=        신규/재방문 고객 수
 * GET /api/stats/reservations?from=&to=     예약 상태별 건수와 노쇼율
 */
@Tag(name = "통계", description = "매출·고객·예약 통계 (조회 전용, ADR 0005)")
@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
public class StatsController {

    private final StatsService statsService;

    @Operation(summary = "일별 매출", description = "from~to의 모든 날짜를 돌려준다. 매출이 없는 날은 0. 최대 366일")
    @GetMapping("/sales/daily")
    public List<DailySales> dailySales(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return statsService.dailySales(from, to);
    }

    @Operation(summary = "월별 매출", description = "해당 연도 1~12월을 항상 돌려준다. 매출이 없는 달은 0")
    @GetMapping("/sales/monthly")
    public List<MonthlySales> monthlySales(@RequestParam int year) {
        return statsService.monthlySales(year);
    }

    @Operation(summary = "메뉴별 매출", description = "기간 내 메뉴별 총액과 건수, 총액이 큰 순")
    @GetMapping("/sales/by-menu")
    public List<MenuSales> salesByMenu(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return statsService.salesByMenu(from, to);
    }

    @Operation(summary = "신규/재방문 고객",
            description = "기간 내 결제한 고객 수. 신규 = 기간 시작 전 결제 이력이 없는 고객, 재방문 = 있는 고객. 한 사람은 1명으로 센다")
    @GetMapping("/customers")
    public CustomerStats customerStats(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return statsService.customerStats(from, to);
    }

    @Operation(summary = "예약 통계", description = "기간 내 시작하는 예약의 상태별 건수. 노쇼율 = 노쇼 / (완료 + 노쇼)")
    @GetMapping("/reservations")
    public ReservationStats reservationStats(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return statsService.reservationStats(from, to);
    }
}
