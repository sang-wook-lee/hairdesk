package com.salonapp.sales;

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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** 매출 API 통합 테스트. 각 테스트가 ADR 0004의 결정 하나씩을 검증한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class SaleApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired StaffRepository staffRepository;

    Staff owner;        // 마이그레이션이 만든 기본 직원(원장)
    Customer customer;
    TreatmentMenu cut;  // 정가 20000원

    @BeforeEach
    void setUp() {
        owner = staffRepository.findByOwnerTrue().orElseThrow();
        customer = customerRepository.save(new Customer("김민지", "01012345678", null, null, false));
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
    }

    @Test
    @DisplayName("예약으로 결제하면 예약이 자동으로 완료 처리되고, 금액을 생략하면 정가가 기록된다")
    void payReservation() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");

        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reservationId":%d,"paymentMethod":"CARD"}
                                """.formatted(reservation.getId())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reservationId").value(reservation.getId()))
                .andExpect(jsonPath("$.customerName").value("김민지"))
                .andExpect(jsonPath("$.menuName").value("커트"))
                .andExpect(jsonPath("$.price").value(20000))
                .andExpect(jsonPath("$.amount").value(20000))
                .andExpect(jsonPath("$.discount").value(0));

        mockMvc.perform(get("/api/reservations/{id}", reservation.getId()))
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    @Test
    @DisplayName("정가보다 적게 받으면 그 차이가 할인액으로 계산된다")
    void discount() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");

        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reservationId":%d,"amount":18000,"paymentMethod":"CASH"}
                                """.formatted(reservation.getId())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.price").value(20000))
                .andExpect(jsonPath("$.amount").value(18000))
                .andExpect(jsonPath("$.discount").value(2000));
    }

    @Test
    @DisplayName("같은 예약에 결제를 두 번 등록할 수 없다 (409)")
    void duplicatePayment() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");
        String body = """
                {"reservationId":%d,"paymentMethod":"CARD"}
                """.formatted(reservation.getId());

        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated());
        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("취소된 예약에는 결제를 등록할 수 없다 (409)")
    void cannotPayCancelledReservation() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");
        reservation.cancel();

        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reservationId":%d,"paymentMethod":"CARD"}
                                """.formatted(reservation.getId())))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("이미 완료 처리된 예약에도 결제를 등록할 수 있다")
    void payAlreadyCompletedReservation() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");
        reservation.complete();

        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reservationId":%d,"paymentMethod":"CARD"}
                                """.formatted(reservation.getId())))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("예약 없이 고객과 메뉴로 워크인 매출을 등록할 수 있고, 여러 건 가능하다")
    void walkIn() throws Exception {
        String body = """
                {"customerId":%d,"menuId":%d,"paymentMethod":"CASH"}
                """.formatted(customer.getId(), cut.getId());

        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reservationId").doesNotExist())
                .andExpect(jsonPath("$.amount").value(20000));
        // reservation_id가 NULL인 매출은 UNIQUE에 걸리지 않는다
        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("예약 ID도 없고 고객/메뉴도 없으면 400")
    void missingTarget() throws Exception {
        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"paymentMethod\":\"CASH\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("예약 ID와 고객/메뉴를 함께 보내면 400 (어느 쪽이 맞는지 모호하다)")
    void ambiguousTarget() throws Exception {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");

        mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reservationId":%d,"customerId":%d,"paymentMethod":"CASH"}
                                """.formatted(reservation.getId(), customer.getId())))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("음수 금액은 400, 0원(무료 서비스)은 허용한다")
    void amountValidation() throws Exception {
        String base = """
                {"customerId":%d,"menuId":%d,"paymentMethod":"CASH","amount":%%d}
                """.formatted(customer.getId(), cut.getId());

        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(base.formatted(-1)))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/sales").contentType(MediaType.APPLICATION_JSON).content(base.formatted(0)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.amount").value(0));
    }

    @Test
    @DisplayName("메뉴 가격이 나중에 바뀌어도 과거 매출의 이름과 정가는 그대로다 (스냅샷)")
    void snapshot() throws Exception {
        long saleId = paySale(cut, 20000, "2026-10-01T05:00:00Z");

        cut.update("프리미엄 커트", MenuCategory.CUT, 35000, 60, 1);
        menuRepository.flush();

        mockMvc.perform(get("/api/sales/{id}", saleId))
                .andExpect(jsonPath("$.menuName").value("커트"))
                .andExpect(jsonPath("$.price").value(20000));
    }

    @Test
    @DisplayName("매출을 정정할 수 있다. 금액/수단/메모는 바뀌지만 정가와 메뉴 이름은 그대로")
    void correct() throws Exception {
        long saleId = paySale(cut, 20000, "2026-10-01T05:00:00Z");

        mockMvc.perform(put("/api/sales/{id}", saleId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount":15000,"paymentMethod":"TRANSFER","paidAt":"2026-10-01T15:00:00+09:00","memo":"지인 할인"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").value(15000))
                .andExpect(jsonPath("$.discount").value(5000))
                .andExpect(jsonPath("$.paymentMethod").value("TRANSFER"))
                .andExpect(jsonPath("$.memo").value("지인 할인"))
                .andExpect(jsonPath("$.price").value(20000));
    }

    @Test
    @DisplayName("기간 조회는 서울 기준 날짜로 자르고 최신순으로 정렬한다")
    void findBetween() throws Exception {
        paySale(cut, 20000, "2026-10-01T09:00:00+09:00");
        paySale(cut, 20000, "2026-10-01T23:30:00+09:00");   // 서울 10/1 (UTC로는 10/1 14:30)
        paySale(cut, 20000, "2026-10-02T00:30:00+09:00");   // 서울 10/2 (UTC로는 10/1 15:30 — UTC로 자르면 10/1로 잘못 들어간다)

        mockMvc.perform(get("/api/sales").param("from", "2026-10-01").param("to", "2026-10-01"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].paidAt").value("2026-10-01T23:30:00+09:00"))  // 최신순
                .andExpect(jsonPath("$[1].paidAt").value("2026-10-01T09:00:00+09:00"));
    }

    @Test
    @DisplayName("요약은 총액, 건수, 결제수단별 합계를 준다")
    void summary() throws Exception {
        paySale(cut, 20000, "CARD", "2026-10-01T10:00:00+09:00");
        paySale(cut, 30000, "CARD", "2026-10-02T10:00:00+09:00");
        paySale(cut, 10000, "CASH", "2026-10-03T10:00:00+09:00");
        paySale(cut, 99999, "CASH", "2026-11-01T10:00:00+09:00");  // 기간 밖

        mockMvc.perform(get("/api/sales/summary").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalAmount").value(60000))
                .andExpect(jsonPath("$.count").value(3))
                .andExpect(jsonPath("$.byMethod", hasSize(2)))
                .andExpect(jsonPath("$.byMethod[?(@.method=='CARD')].totalAmount").value(50000))
                .andExpect(jsonPath("$.byMethod[?(@.method=='CASH')].count").value(1));
    }

    @Test
    @DisplayName("기간에 매출이 없으면 요약은 0이다")
    void emptySummary() throws Exception {
        mockMvc.perform(get("/api/sales/summary").param("from", "2026-10-01").param("to", "2026-10-31"))
                .andExpect(jsonPath("$.totalAmount").value(0))
                .andExpect(jsonPath("$.count").value(0))
                .andExpect(jsonPath("$.byMethod", hasSize(0)));
    }

    @Test
    @DisplayName("서비스 확인을 우회해도 DB의 UNIQUE 제약이 이중 결제를 막는다")
    void databaseConstraintIsLastDefense() {
        Reservation reservation = bookedReservation("2026-10-01T05:00:00Z");
        saleRepository.saveAndFlush(Sale.forReservation(reservation, null, PaymentMethod.CARD, Instant.now(), null));

        Sale second = Sale.forReservation(reservation, null, PaymentMethod.CASH, Instant.now(), null);
        assertThatThrownBy(() -> saleRepository.saveAndFlush(second))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private Reservation bookedReservation(String startAt) {
        return reservationRepository.saveAndFlush(new Reservation(customer, cut, owner, Instant.parse(startAt), null));
    }

    private long paySale(TreatmentMenu menu, int amount, String paidAt) throws Exception {
        return paySale(menu, amount, "CARD", paidAt);
    }

    /** 워크인 매출을 API로 등록하고 id를 돌려준다. */
    private long paySale(TreatmentMenu menu, int amount, String method, String paidAt) throws Exception {
        String body = mockMvc.perform(post("/api/sales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"customerId":%d,"menuId":%d,"amount":%d,"paymentMethod":"%s","paidAt":"%s"}
                                """.formatted(customer.getId(), menu.getId(), amount, method, paidAt)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+).*", "$1"));
    }
}
