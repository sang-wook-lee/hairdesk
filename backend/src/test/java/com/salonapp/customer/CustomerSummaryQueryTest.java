package com.salonapp.customer;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.dto.CustomerSaleTotals;
import com.salonapp.customer.dto.ReservationStatusCount;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.PaymentMethod;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 고객 요약(방문 횟수, 총 결제액, 첫·최근 방문일, 최근 시술, 예약 상태별 건수)에 쓰는 저장소 쿼리 3개를
 * 실제 PostgreSQL에서 확인한다.
 *
 * 저장소 쿼리만 시험한다. 응답 모양과 404 같은 것은 서비스·컨트롤러를 만든 뒤 API 테스트에서 본다.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@Transactional
class CustomerSummaryQueryTest {

    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired StaffRepository staffRepository;
    @Autowired EntityManager entityManager;

    Staff director;      // V6 마이그레이션이 만든 기본 직원(원장)
    Staff jisoo;
    Customer minji;
    Customer haneul;
    TreatmentMenu cut;   // 정가 20000
    TreatmentMenu perm;  // 정가 80000

    @BeforeEach
    void setUp() {
        director = staffRepository.findAllByOrderByIdAsc().get(0);
        jisoo = staffRepository.save(new Staff("이지수", "실장"));
        minji = customerRepository.save(new Customer("김민지", "01012345678", null, null, false));
        haneul = customerRepository.save(new Customer("이하늘", "01099990000", null, null, false));
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
        perm = menuRepository.save(new TreatmentMenu("펌", MenuCategory.PERM, 80000, 120, 2));
    }

    // ---- ㉠ 매출 집계 ----

    @Test
    @DisplayName("매출이 없는 고객은 횟수 0, 합계와 날짜는 null로 나온다 (0이 아니다)")
    void totalsOfCustomerWithoutSales() {
        CustomerSaleTotals totals = saleRepository.totalsByCustomer(minji.getId());

        assertThat(totals.visitCount()).isZero();
        assertThat(totals.totalAmount()).isNull();
        assertThat(totals.firstVisitAt()).isNull();
        assertThat(totals.lastVisitAt()).isNull();
    }

    @Test
    @DisplayName("방문 횟수와 총 결제액은 실제 받은 금액으로 세고, 첫·최근 방문일은 저장한 순서가 아니라 결제 시각으로 정한다")
    void totalsCountAmountAndDates() {
        // 일부러 시간 순서를 섞어서 저장한다. 저장 순서로 첫/마지막을 정하면 틀린다.
        sell(minji, cut, director, 18000, "2026-10-10T10:00:00+09:00");   // 가운데
        sell(minji, perm, director, 70000, "2026-10-20T10:00:00+09:00");  // 가장 최근
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");   // 가장 처음

        CustomerSaleTotals totals = saleRepository.totalsByCustomer(minji.getId());

        assertThat(totals.visitCount()).isEqualTo(3);
        assertThat(totals.totalAmount()).isEqualTo(18000 + 70000 + 20000);  // 정가(20000+80000+20000)가 아니라 받은 금액
        assertThat(totals.firstVisitAt()).isEqualTo(at("2026-10-01T10:00:00+09:00"));
        assertThat(totals.lastVisitAt()).isEqualTo(at("2026-10-20T10:00:00+09:00"));
    }

    @Test
    @DisplayName("방문은 매출 기록으로 센다: 예약 없이 온 손님(워크인)과 예약 결제 모두 포함하고, 결제 안 한 예약은 방문이 아니다")
    void visitsAreSalesRecords() {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");                    // 워크인
        Reservation paid = reserve(minji, "2026-10-05T01:00:00Z", director);
        paid.complete();
        saleRepository.saveAndFlush(Sale.forReservation(paid, null, PaymentMethod.CARD,
                at("2026-10-05T10:30:00+09:00"), null));                                    // 예약 결제
        reserve(minji, "2026-10-08T01:00:00Z", director);                                   // 아직 예약됨(결제 없음)

        CustomerSaleTotals totals = saleRepository.totalsByCustomer(minji.getId());

        assertThat(totals.visitCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("다른 고객의 매출은 섞이지 않는다")
    void totalsDoNotMixCustomers() {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(haneul, perm, director, 80000, "2026-10-02T10:00:00+09:00");
        sell(haneul, perm, director, 80000, "2026-10-03T10:00:00+09:00");

        CustomerSaleTotals totals = saleRepository.totalsByCustomer(minji.getId());

        assertThat(totals.visitCount()).isEqualTo(1);
        assertThat(totals.totalAmount()).isEqualTo(20000);
        assertThat(totals.lastVisitAt()).isEqualTo(at("2026-10-01T10:00:00+09:00"));
    }

    // ---- ㉡ 최근 결제 1건 ----

    @Test
    @DisplayName("매출이 없는 고객은 최근 결제가 없다")
    void latestSaleOfCustomerWithoutSales() {
        assertThat(saleRepository.findFirstByCustomerIdOrderByPaidAtDescIdDesc(minji.getId())).isEmpty();
    }

    @Test
    @DisplayName("최근 결제는 가장 나중에 저장한 것이 아니라 결제 시각이 가장 늦은 것이다 (메뉴와 담당도 그 결제의 것)")
    void latestSaleIsByPaidAt() {
        // 가장 최근 결제(펌, 이지수)를 먼저 저장하고, 더 오래된 결제를 나중에 저장한다.
        sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(haneul, cut, director, 20000, "2026-10-25T10:00:00+09:00");   // 다른 고객의 더 최근 결제는 무시

        Sale latest = saleRepository.findFirstByCustomerIdOrderByPaidAtDescIdDesc(minji.getId()).orElseThrow();

        assertThat(latest.getMenuName()).isEqualTo("펌");
        assertThat(latest.getStaff().getId()).isEqualTo(jisoo.getId());
    }

    @Test
    @DisplayName("같은 시각에 결제가 둘이면 번호가 큰 쪽이 최근이다 (결과가 항상 같게)")
    void latestSaleTieBreaksById() {
        sell(minji, cut, director, 20000, "2026-10-20T10:00:00+09:00");
        Sale second = sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");

        Sale latest = saleRepository.findFirstByCustomerIdOrderByPaidAtDescIdDesc(minji.getId()).orElseThrow();

        assertThat(latest.getId()).isEqualTo(second.getId());
    }

    @Test
    @DisplayName("최근 결제를 가져올 때 담당자도 함께 가져온다 (이름을 보여주려고 쿼리가 또 나가지 않는다)")
    void latestSaleLoadsStaffTogether() {
        sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");
        entityManager.clear();   // 저장하면서 이미 메모리에 올라온 객체가 아니라 DB에서 새로 읽게 한다

        Sale latest = saleRepository.findFirstByCustomerIdOrderByPaidAtDescIdDesc(minji.getId()).orElseThrow();

        boolean staffLoaded = entityManager.getEntityManagerFactory().getPersistenceUnitUtil()
                .isLoaded(latest.getStaff());
        assertThat(staffLoaded).isTrue();
    }

    // ---- ㉢ 예약 상태별 건수 ----

    @Test
    @DisplayName("예약이 없는 고객은 상태별 건수 줄이 하나도 없다")
    void statusCountsOfCustomerWithoutReservations() {
        assertThat(reservationRepository.countByStatusForCustomer(minji.getId())).isEmpty();
    }

    @Test
    @DisplayName("예약 상태별 건수를 센다 (예약됨·완료·취소·노쇼)")
    void statusCounts() {
        reserve(minji, "2026-10-01T01:00:00Z", director).complete();
        reserve(minji, "2026-10-02T01:00:00Z", director).complete();
        reserve(minji, "2026-10-03T01:00:00Z", director).cancel();
        reserve(minji, "2026-10-04T01:00:00Z", director).markNoShow();
        reserve(minji, "2026-10-05T01:00:00Z", director);   // 예약됨 그대로
        entityManager.flush();

        List<ReservationStatusCount> counts = reservationRepository.countByStatusForCustomer(minji.getId());

        assertThat(counts).containsExactlyInAnyOrder(
                new ReservationStatusCount(ReservationStatus.BOOKED, 1),
                new ReservationStatusCount(ReservationStatus.COMPLETED, 2),
                new ReservationStatusCount(ReservationStatus.CANCELLED, 1),
                new ReservationStatusCount(ReservationStatus.NO_SHOW, 1));
    }

    @Test
    @DisplayName("다른 고객의 예약은 세지 않는다")
    void statusCountsDoNotMixCustomers() {
        reserve(minji, "2026-10-01T01:00:00Z", director).complete();
        reserve(haneul, "2026-10-02T01:00:00Z", director).markNoShow();
        reserve(haneul, "2026-10-03T01:00:00Z", director).markNoShow();
        entityManager.flush();

        List<ReservationStatusCount> counts = reservationRepository.countByStatusForCustomer(minji.getId());

        assertThat(counts).containsExactly(new ReservationStatusCount(ReservationStatus.COMPLETED, 1));
    }

    // ---- 도우미 ----

    private Instant at(String iso) {
        return OffsetDateTime.parse(iso).toInstant();
    }

    private Sale sell(Customer customer, TreatmentMenu menu, Staff staff, int amount, String paidAt) {
        return saleRepository.saveAndFlush(
                Sale.walkIn(customer, menu, staff, amount, PaymentMethod.CARD, at(paidAt), null));
    }

    /** 커트(60분)로 예약한다. 같은 직원의 시간이 겹치지 않게 테스트마다 날짜를 다르게 준다. */
    private Reservation reserve(Customer customer, String startAtUtc, Staff staff) {
        return reservationRepository.saveAndFlush(new Reservation(customer, cut, staff, at(startAtUtc), null));
    }
}
