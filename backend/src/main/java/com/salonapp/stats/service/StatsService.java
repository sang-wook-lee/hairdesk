package com.salonapp.stats.service;

import com.salonapp.common.time.SeoulDates;
import com.salonapp.stats.dto.CustomerStats;
import com.salonapp.stats.dto.DailySales;
import com.salonapp.stats.dto.MenuSales;
import com.salonapp.stats.dto.MonthlySales;
import com.salonapp.stats.dto.ReservationStats;
import com.salonapp.stats.repository.ReservationStatsRepository;
import com.salonapp.stats.repository.SalesStatsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 통계. 모든 메서드가 조회 전용이라 클래스 전체를 readOnly 트랜잭션으로 둔다.
 * 날짜 → 시각 범위 변환은 SeoulDates로 하고, DB에는 항상 [from, to) 범위로 묻는다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StatsService {

    /** 일별 조회 최대 일수. 실수로 아주 긴 기간을 요청해 응답이 커지는 걸 막는다. */
    static final int MAX_DAILY_RANGE_DAYS = 366;

    private final SalesStatsRepository salesStats;
    private final ReservationStatsRepository reservationStats;

    /**
     * 일별 매출. DB는 매출이 있는 날만 돌려주므로, from~to의 모든 날짜를 돌면서 없는 날은 0으로 채운다.
     */
    public List<DailySales> dailySales(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        long days = ChronoUnit.DAYS.between(from, to) + 1;
        if (days > MAX_DAILY_RANGE_DAYS) {
            throw new IllegalArgumentException("일별 통계는 최대 " + MAX_DAILY_RANGE_DAYS + "일까지 조회할 수 있습니다.");
        }

        // 날짜 문자열 → 그날 집계. 아래에서 날짜로 바로 꺼내 쓰려고 Map으로 만든다.
        Map<String, SalesStatsRepository.DayRow> byDay = new HashMap<>();
        for (SalesStatsRepository.DayRow row : salesStats.sumByDay(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to))) {
            byDay.put(row.getDay(), row);
        }

        List<DailySales> result = new ArrayList<>();
        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            SalesStatsRepository.DayRow row = byDay.get(date.toString());   // LocalDate.toString() = "2026-10-01"
            result.add(row == null
                    ? new DailySales(date, 0, 0)
                    : new DailySales(date, row.getTotal(), row.getCnt()));
        }
        return result;
    }

    /** 월별 매출. 1월~12월 12개를 항상 돌려준다(없는 달은 0). */
    public List<MonthlySales> monthlySales(int year) {
        LocalDate from = LocalDate.of(year, 1, 1);
        LocalDate to = LocalDate.of(year, 12, 31);

        Map<String, SalesStatsRepository.MonthRow> byMonth = new HashMap<>();
        for (SalesStatsRepository.MonthRow row : salesStats.sumByMonth(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to))) {
            byMonth.put(row.getYm(), row);
        }

        List<MonthlySales> result = new ArrayList<>();
        for (int month = 1; month <= 12; month++) {
            String key = YearMonth.of(year, month).toString();   // "2026-10"
            SalesStatsRepository.MonthRow row = byMonth.get(key);
            result.add(row == null
                    ? new MonthlySales(key, 0, 0)
                    : new MonthlySales(key, row.getTotal(), row.getCnt()));
        }
        return result;
    }

    /** 메뉴별 매출, 많이 번 순 */
    public List<MenuSales> salesByMenu(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        return salesStats.sumByMenu(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to));
    }

    /** 신규/재방문 고객 (정의: ADR 0005) */
    public CustomerStats customerStats(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        var start = SeoulDates.startOfDay(from);
        var end = SeoulDates.endOfDayExclusive(to);
        long total = salesStats.countCustomers(start, end);
        long returning = salesStats.countReturningCustomers(start, end);
        return new CustomerStats(total, total - returning, returning);
    }

    public ReservationStats reservationStats(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        return ReservationStats.from(
                reservationStats.countByStatus(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to)));
    }

    private void requireValidRange(LocalDate from, LocalDate to) {
        if (to.isBefore(from)) {
            throw new IllegalArgumentException("종료 날짜가 시작 날짜보다 빠릅니다.");
        }
    }
}
