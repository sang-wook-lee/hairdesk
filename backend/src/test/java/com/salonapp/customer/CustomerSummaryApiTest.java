package com.salonapp.customer;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.PaymentMethod;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /api/customers/{id}/summary 통합 테스트.
 * 쿼리 자체(횟수, 합계, 최근 결제 선택)는 CustomerSummaryQueryTest에서 봤으므로,
 * 여기서는 응답에 담기는 모양과 서비스가 직접 하는 계산(null→0, 평균, 취소·노쇼 합산, 404)을 본다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class CustomerSummaryApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired StaffRepository staffRepository;

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

    @Test
    @DisplayName("기록이 없는 고객은 횟수와 금액이 0이고, 날짜·평균·최근 시술은 null이다")
    void customerWithoutRecords() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.visitCount").value(0))
                .andExpect(jsonPath("$.totalAmount").value(0))
                .andExpect(jsonPath("$.reservationCount").value(0))
                .andExpect(jsonPath("$.cancelledCount").value(0))
                .andExpect(jsonPath("$.noShowCount").value(0))
                .andExpect(jsonPath("$.firstVisitAt").value(nullValue()))
                .andExpect(jsonPath("$.lastVisitAt").value(nullValue()))
                .andExpect(jsonPath("$.averageAmount").value(nullValue()))
                .andExpect(jsonPath("$.lastMenuName").value(nullValue()))
                .andExpect(jsonPath("$.lastStaffId").value(nullValue()))
                .andExpect(jsonPath("$.lastStaffName").value(nullValue()))
                .andExpect(jsonPath("$.lastStaffPosition").value(nullValue()));
    }

    @Test
    @DisplayName("방문 횟수·총 결제액·첫/최근 방문일이 서울 시간(+09:00)으로 나온다")
    void visitsAndDates() throws Exception {
        sell(minji, cut, director, 18000, "2026-10-01T10:00:00+09:00");
        sell(minji, perm, jisoo, 70000, "2026-10-20T15:30:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.visitCount").value(2))
                .andExpect(jsonPath("$.totalAmount").value(88000))        // 정가 합(100000)이 아니라 받은 금액
                .andExpect(jsonPath("$.firstVisitAt").value("2026-10-01T10:00:00+09:00"))
                .andExpect(jsonPath("$.lastVisitAt").value("2026-10-20T15:30:00+09:00"));
    }

    @Test
    @DisplayName("평균 결제액은 원 단위로 반올림한다 (10000원과 10001원이면 10001원)")
    void averageIsRounded() throws Exception {
        sell(minji, cut, director, 10000, "2026-10-01T10:00:00+09:00");
        sell(minji, cut, director, 10001, "2026-10-02T10:00:00+09:00");   // 평균 10000.5 → 반올림 10001

        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(jsonPath("$.averageAmount").value(10001));
    }

    @Test
    @DisplayName("최근 시술 메뉴와 담당은 가장 최근 결제의 것이고, 담당은 번호·이름·직책이 함께 나온다")
    void latestMenuAndStaff() throws Exception {
        sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");     // 가장 최근
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(jsonPath("$.lastMenuName").value("펌"))
                .andExpect(jsonPath("$.lastStaffId").value(jisoo.getId()))
                .andExpect(jsonPath("$.lastStaffName").value("이지수"))
                .andExpect(jsonPath("$.lastStaffPosition").value("실장"));
    }

    @Test
    @DisplayName("예약 수는 모든 상태를 합친 것이고, 취소와 노쇼는 따로 센다. 방문(매출)과는 별개다")
    void reservationCounts() throws Exception {
        reserve(minji, "2026-10-01T01:00:00Z").complete();
        reserve(minji, "2026-10-02T01:00:00Z").cancel();
        reserve(minji, "2026-10-03T01:00:00Z").cancel();
        reserve(minji, "2026-10-04T01:00:00Z").markNoShow();
        reserve(minji, "2026-10-05T01:00:00Z");                            // 예약됨 그대로

        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(jsonPath("$.reservationCount").value(5))
                .andExpect(jsonPath("$.cancelledCount").value(2))
                .andExpect(jsonPath("$.noShowCount").value(1))
                .andExpect(jsonPath("$.visitCount").value(0));            // 결제한 적 없으니 방문은 0
    }

    @Test
    @DisplayName("다른 고객의 매출·예약은 요약에 섞이지 않는다")
    void doesNotMixCustomers() throws Exception {
        sell(haneul, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");
        reserve(haneul, "2026-10-03T01:00:00Z").markNoShow();

        mockMvc.perform(get("/api/customers/{id}/summary", minji.getId()))
                .andExpect(jsonPath("$.visitCount").value(0))
                .andExpect(jsonPath("$.totalAmount").value(0))
                .andExpect(jsonPath("$.reservationCount").value(0))
                .andExpect(jsonPath("$.noShowCount").value(0))
                .andExpect(jsonPath("$.lastMenuName").value(nullValue()));
    }

    @Test
    @DisplayName("없는 고객은 404와 안내 메시지를 준다 (기록 0건인 고객처럼 200으로 보이지 않는다)")
    void unknownCustomerIs404() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/summary", 999999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("고객을 찾을 수 없습니다. id=999999"));
    }

    // ---- 도우미 ----

    private Instant at(String iso) {
        return OffsetDateTime.parse(iso).toInstant();
    }

    private void sell(Customer customer, TreatmentMenu menu, Staff staff, int amount, String paidAt) {
        saleRepository.saveAndFlush(Sale.walkIn(customer, menu, staff, amount, PaymentMethod.CARD, at(paidAt), null));
    }

    /** 커트(60분), 원장으로 예약한다. 같은 직원의 시간이 겹치지 않게 테스트마다 날짜를 다르게 준다. */
    private Reservation reserve(Customer customer, String startAtUtc) {
        return reservationRepository.saveAndFlush(new Reservation(customer, cut, director, at(startAtUtc), null));
    }
}
