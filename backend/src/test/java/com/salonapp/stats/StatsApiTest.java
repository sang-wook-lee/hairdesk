package com.salonapp.stats;

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

import java.time.OffsetDateTime;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** 통계 API 통합 테스트. 각 테스트가 ADR 0005의 결정 하나씩을 검증한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class StatsApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired StaffRepository staffRepository;

    Staff defaultStaff;         // V6 마이그레이션이 만든 기본 직원(원장)
    Customer minji;
    Customer haneul;
    TreatmentMenu cut;   // 정가 20000
    TreatmentMenu perm;  // 정가 80000

    @BeforeEach
    void setUp() {
        defaultStaff = staffRepository.findAllByOrderByIdAsc().get(0);
        minji = customerRepository.save(new Customer("김민지", "01012345678", null, null, false));
        haneul = customerRepository.save(new Customer("이하늘", "01099990000", null, null, false));
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
        perm = menuRepository.save(new TreatmentMenu("펌", MenuCategory.PERM, 80000, 120, 2));
    }

    // ---- 일별 매출 ----

    @Test
    @DisplayName("일별 매출은 서울 날짜로 묶는다 (자정 근처 매출이 UTC 때문에 하루 밀리지 않는다)")
    void dailyUsesSeoulDate() throws Exception {
        sell(minji, cut, 20000, "2026-10-01T09:00:00+09:00");
        sell(minji, cut, 10000, "2026-10-01T23:30:00+09:00");   // 서울 10/1 (UTC로는 10/1 14:30)
        sell(minji, cut, 5000, "2026-10-02T00:30:00+09:00");    // 서울 10/2 (UTC로는 10/1 15:30 — UTC로 묶으면 10/1로 잘못 합쳐진다)

        mockMvc.perform(get("/api/stats/sales/daily").param("from", "2026-10-01").param("to", "2026-10-02"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].date").value("2026-10-01"))
                .andExpect(jsonPath("$[0].totalAmount").value(30000))
                .andExpect(jsonPath("$[0].count").value(2))
                .andExpect(jsonPath("$[1].date").value("2026-10-02"))
                .andExpect(jsonPath("$[1].totalAmount").value(5000))
                .andExpect(jsonPath("$[1].count").value(1));
    }

    @Test
    @DisplayName("일별 매출은 매출이 없는 날도 0으로 채워서 준다")
    void dailyZeroFill() throws Exception {
        sell(minji, cut, 20000, "2026-10-01T10:00:00+09:00");
        sell(minji, cut, 20000, "2026-10-03T10:00:00+09:00");

        mockMvc.perform(get("/api/stats/sales/daily").param("from", "2026-10-01").param("to", "2026-10-04"))
                .andExpect(jsonPath("$", hasSize(4)))
                .andExpect(jsonPath("$[1].date").value("2026-10-02"))
                .andExpect(jsonPath("$[1].totalAmount").value(0))
                .andExpect(jsonPath("$[1].count").value(0))
                .andExpect(jsonPath("$[3].totalAmount").value(0));
    }

    @Test
    @DisplayName("일별 조회 기간이 366일을 넘으면 400")
    void dailyRangeLimit() throws Exception {
        mockMvc.perform(get("/api/stats/sales/daily").param("from", "2026-01-01").param("to", "2027-01-02"))  // 367일
                .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/stats/sales/daily").param("from", "2026-01-01").param("to", "2026-12-31"))  // 365일
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("종료 날짜가 시작 날짜보다 빠르면 400")
    void invalidRange() throws Exception {
        mockMvc.perform(get("/api/stats/sales/daily").param("from", "2026-10-02").param("to", "2026-10-01"))
                .andExpect(status().isBadRequest());
    }

    // ---- 월별 매출 ----

    @Test
    @DisplayName("월별 매출은 12개월을 항상 주고, 서울 기준으로 달을 나눈다")
    void monthly() throws Exception {
        sell(minji, cut, 20000, "2026-10-05T10:00:00+09:00");
        sell(minji, perm, 80000, "2026-10-31T23:30:00+09:00");   // 서울 10월 (UTC로도 10월이지만)
        sell(minji, cut, 30000, "2026-11-01T00:30:00+09:00");    // 서울 11월 (UTC로는 10/31 15:30 — UTC로 묶으면 10월로 잘못 들어간다)

        mockMvc.perform(get("/api/stats/sales/monthly").param("year", "2026"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(12)))
                .andExpect(jsonPath("$[0].month").value("2026-01"))
                .andExpect(jsonPath("$[0].totalAmount").value(0))
                .andExpect(jsonPath("$[9].month").value("2026-10"))
                .andExpect(jsonPath("$[9].totalAmount").value(100000))
                .andExpect(jsonPath("$[9].count").value(2))
                .andExpect(jsonPath("$[10].month").value("2026-11"))
                .andExpect(jsonPath("$[10].totalAmount").value(30000));
    }

    // ---- 메뉴별 매출 ----

    @Test
    @DisplayName("메뉴별 매출은 총액이 큰 순으로 나온다")
    void byMenu() throws Exception {
        sell(minji, cut, 20000, "2026-10-01T10:00:00+09:00");
        sell(haneul, cut, 20000, "2026-10-02T10:00:00+09:00");
        sell(minji, cut, 20000, "2026-10-03T10:00:00+09:00");  // 커트 3건 = 60000
        sell(haneul, perm, 80000, "2026-10-04T10:00:00+09:00"); // 펌 1건 = 80000
        sell(minji, perm, 80000, "2026-11-01T10:00:00+09:00");  // 기간 밖

        mockMvc.perform(get("/api/stats/sales/by-menu").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].menuName").value("펌"))
                .andExpect(jsonPath("$[0].totalAmount").value(80000))
                .andExpect(jsonPath("$[0].count").value(1))
                .andExpect(jsonPath("$[1].menuName").value("커트"))
                .andExpect(jsonPath("$[1].totalAmount").value(60000))
                .andExpect(jsonPath("$[1].count").value(3));
    }

    @Test
    @DisplayName("메뉴 이름을 바꿔도 매출이 둘로 쪼개지지 않고 현재 이름으로 합쳐진다")
    void byMenuAfterRename() throws Exception {
        sell(minji, cut, 20000, "2026-10-01T10:00:00+09:00");
        cut.update("프리미엄 커트", MenuCategory.CUT, 25000, 60, 1);
        menuRepository.flush();
        sell(minji, cut, 25000, "2026-10-02T10:00:00+09:00");

        mockMvc.perform(get("/api/stats/sales/by-menu").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].menuName").value("프리미엄 커트"))
                .andExpect(jsonPath("$[0].totalAmount").value(45000))
                .andExpect(jsonPath("$[0].count").value(2));
    }

    // ---- 신규/재방문 고객 ----

    @Test
    @DisplayName("기간 시작 전에 결제 이력이 있으면 재방문, 없으면 신규다")
    void newVsReturning() throws Exception {
        sell(minji, cut, 20000, "2026-09-15T10:00:00+09:00");   // 민지: 9월에 이미 왔음
        sell(minji, cut, 20000, "2026-10-05T10:00:00+09:00");   // 민지: 10월에 재방문
        sell(haneul, cut, 20000, "2026-10-06T10:00:00+09:00");  // 하늘: 10월이 첫 방문

        mockMvc.perform(get("/api/stats/customers").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCustomers").value(2))
                .andExpect(jsonPath("$.newCustomers").value(1))
                .andExpect(jsonPath("$.returningCustomers").value(1));
    }

    @Test
    @DisplayName("같은 기간에 여러 번 와도 1명으로 세고, 그 기간이 첫 방문이면 신규다")
    void sameCustomerMultipleTimesCountsOnce() throws Exception {
        sell(haneul, cut, 20000, "2026-10-06T10:00:00+09:00");
        sell(haneul, perm, 80000, "2026-10-20T10:00:00+09:00");  // 같은 달 두 번째 방문: 여전히 "이번 달 신규" 1명

        mockMvc.perform(get("/api/stats/customers").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(jsonPath("$.totalCustomers").value(1))
                .andExpect(jsonPath("$.newCustomers").value(1))
                .andExpect(jsonPath("$.returningCustomers").value(0));
    }

    @Test
    @DisplayName("고객 카드만 있고 결제한 적 없는 사람은 신규로 세지 않는다")
    void cardWithoutSaleIsNotCounted() throws Exception {
        // setUp에서 두 고객 카드가 만들어졌지만 결제는 없다.
        mockMvc.perform(get("/api/stats/customers").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(jsonPath("$.totalCustomers").value(0))
                .andExpect(jsonPath("$.newCustomers").value(0))
                .andExpect(jsonPath("$.returningCustomers").value(0));
    }

    // ---- 예약 통계 ----

    @Test
    @DisplayName("노쇼율은 노쇼 / (완료 + 노쇼). 예정과 취소는 분모에서 뺀다")
    void reservationStats() throws Exception {
        reserve("2026-10-01T01:00:00Z").complete();
        reserve("2026-10-01T03:00:00Z").complete();
        reserve("2026-10-01T05:00:00Z").complete();
        reserve("2026-10-01T07:00:00Z").markNoShow();   // 완료 3 + 노쇼 1 → 25%
        reserve("2026-10-01T09:00:00Z").cancel();
        reservationRepository.flush();
        reserve("2026-10-01T11:00:00Z");                // 예정(BOOKED) 1건

        mockMvc.perform(get("/api/stats/reservations").param("from", "2026-10-01").param("to", "2026-10-01"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completed").value(3))
                .andExpect(jsonPath("$.noShow").value(1))
                .andExpect(jsonPath("$.cancelled").value(1))
                .andExpect(jsonPath("$.booked").value(1))
                .andExpect(jsonPath("$.noShowRate").value(0.25));
    }

    @Test
    @DisplayName("결과가 난 예약이 없으면 노쇼율은 0이다 (0으로 나누지 않는다)")
    void noShowRateWithoutDecidedReservations() throws Exception {
        mockMvc.perform(get("/api/stats/reservations").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(jsonPath("$.completed").value(0))
                .andExpect(jsonPath("$.noShow").value(0))
                .andExpect(jsonPath("$.noShowRate").value(0.0));
    }

    // ---- 테스트 데이터 도우미 ----

    /** 워크인 매출을 저장소로 바로 넣는다 (통계 검증에 집중하려고 API를 거치지 않는다). */
    private void sell(Customer customer, TreatmentMenu menu, int amount, String paidAt) {
        saleRepository.saveAndFlush(Sale.walkIn(customer, menu, defaultStaff, amount, PaymentMethod.CARD,
                OffsetDateTime.parse(paidAt).toInstant(), null));
    }

    /** 예약(BOOKED)을 저장하고 돌려준다. 시간은 호출부에서 서로 겹치지 않게 2시간 간격으로 준다. */
    private Reservation reserve(String startAtUtc) {
        return reservationRepository.saveAndFlush(
                new Reservation(minji, cut, defaultStaff, OffsetDateTime.parse(startAtUtc).toInstant(), null));
    }
}
