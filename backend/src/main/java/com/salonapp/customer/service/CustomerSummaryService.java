package com.salonapp.customer.service;

import com.salonapp.common.exception.NotFoundException;
import com.salonapp.common.time.SeoulDates;
import com.salonapp.customer.dto.CustomerSaleTotals;
import com.salonapp.customer.dto.CustomerSummaryResponse;
import com.salonapp.customer.dto.ReservationStatusCount;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.reservation.domain.ReservationStatus;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * 고객 한 명의 요약(방문 횟수, 총 결제액, 첫·최근 방문일, 최근 시술, 예약 통계)을 만든다.
 *
 * 기존 CustomerService는 고객 카드(등록·검색·수정)만 다룬다. 여기서는 매출·예약 저장소까지 쓰기 때문에
 * 역할이 섞이지 않게 따로 뒀다. DB는 3번 조회하고, 합치는 일만 이 서비스가 한다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CustomerSummaryService {

    private final CustomerRepository customerRepository;
    private final SaleRepository saleRepository;
    private final ReservationRepository reservationRepository;

    public CustomerSummaryResponse summarize(Long customerId) {
        // 없는 고객이면 "기록이 0건인 고객"처럼 보이지 않게 먼저 404를 준다.
        if (!customerRepository.existsById(customerId)) {
            throw new NotFoundException("고객을 찾을 수 없습니다. id=" + customerId);
        }

        CustomerSaleTotals totals = saleRepository.totalsByCustomer(customerId);
        Sale latest = saleRepository.findFirstByCustomerIdOrderByPaidAtDescIdDesc(customerId).orElse(null);
        List<ReservationStatusCount> statusCounts = reservationRepository.countByStatusForCustomer(customerId);

        long totalAmount = totals.totalAmount() == null ? 0 : totals.totalAmount(); // SUM은 행이 없으면 null
        Long averageAmount = totals.visitCount() == 0
                ? null
                : Math.round((double) totalAmount / totals.visitCount());

        return new CustomerSummaryResponse(
                totals.visitCount(),
                toSeoul(totals.firstVisitAt()),
                toSeoul(totals.lastVisitAt()),
                totalAmount,
                averageAmount,
                statusCounts.stream().mapToLong(ReservationStatusCount::count).sum(),
                countOf(statusCounts, ReservationStatus.CANCELLED),
                countOf(statusCounts, ReservationStatus.NO_SHOW),
                latest == null ? null : latest.getMenuName(),
                latest == null ? null : latest.getStaff().getId(),
                latest == null ? null : latest.getStaff().getName(),
                latest == null ? null : latest.getStaff().getPosition()
        );
    }

    /** 상태별 건수 목록에서 한 상태의 건수. 그 상태의 예약이 없으면 줄이 없으므로 0이다. */
    private static long countOf(List<ReservationStatusCount> counts, ReservationStatus status) {
        return counts.stream()
                .filter(c -> c.status() == status)
                .mapToLong(ReservationStatusCount::count)
                .findFirst()
                .orElse(0);
    }

    private static OffsetDateTime toSeoul(Instant instant) {
        return instant == null ? null : instant.atZone(SeoulDates.SEOUL).toOffsetDateTime();
    }
}
