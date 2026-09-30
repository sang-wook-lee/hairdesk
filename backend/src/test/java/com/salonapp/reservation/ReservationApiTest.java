package com.salonapp.reservation;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.repository.ReservationRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** 예약 API 통합 테스트. 겹침 방지 규칙(ADR 0003)을 하나씩 검증한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class ReservationApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;

    Customer customer;
    TreatmentMenu cut;   // 60분
    TreatmentMenu perm;  // 120분

    @BeforeEach
    void setUp() {
        customer = customerRepository.save(new Customer("김민지", "01012345678", null, null, false));
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
        perm = menuRepository.save(new TreatmentMenu("펌", MenuCategory.PERM, 80000, 120, 2));
    }

    @Test
    @DisplayName("예약하면 종료 시각이 시작 + 메뉴 소요시간으로 계산되고, 서울 시간으로 응답한다")
    void createCalculatesEndTime() throws Exception {
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T14:00:00+09:00")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.startAt").value("2026-10-01T14:00:00+09:00"))
                .andExpect(jsonPath("$.endAt").value("2026-10-01T15:00:00+09:00"))
                .andExpect(jsonPath("$.status").value("BOOKED"))
                .andExpect(jsonPath("$.customerName").value("김민지"))
                .andExpect(jsonPath("$.menuName").value("커트"));
    }

    @Test
    @DisplayName("겹치는 시간에는 예약할 수 없다 (409)")
    void overlapRejected() throws Exception {
        book(cut, "2026-10-01T14:00:00+09:00");  // 14:00~15:00

        // 14:30~15:30 → 뒷부분이 겹침
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T14:30:00+09:00")))
                .andExpect(status().isConflict());

        // 13:30~14:30 → 앞부분이 겹침
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T13:30:00+09:00")))
                .andExpect(status().isConflict());

        // 13:00~15:00(펌) → 기존 예약을 통째로 감쌈
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(perm.getId(), "2026-10-01T13:30:00+09:00")))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("앞 예약이 끝나는 시각에 다음 예약이 시작하는 것은 허용한다")
    void backToBackAllowed() throws Exception {
        book(cut, "2026-10-01T14:00:00+09:00");  // 14:00~15:00

        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T15:00:00+09:00")))
                .andExpect(status().isCreated());
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T13:00:00+09:00")))  // 13:00~14:00
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("취소한 예약의 시간에는 다시 예약할 수 있다")
    void cancelFreesSlot() throws Exception {
        long id = book(cut, "2026-10-01T14:00:00+09:00");

        mockMvc.perform(post("/api/reservations/{id}/cancel", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));

        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T14:00:00+09:00")))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("노쇼 처리한 예약의 시간에도 다시 예약할 수 있다")
    void noShowFreesSlot() throws Exception {
        long id = book(cut, "2026-10-01T14:00:00+09:00");

        mockMvc.perform(post("/api/reservations/{id}/no-show", id))
                .andExpect(jsonPath("$.status").value("NO_SHOW"));

        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T14:00:00+09:00")))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("이미 취소된 예약은 완료 처리할 수 없다 (409)")
    void cannotCompleteCancelled() throws Exception {
        long id = book(cut, "2026-10-01T14:00:00+09:00");
        mockMvc.perform(post("/api/reservations/{id}/cancel", id)).andExpect(status().isOk());

        mockMvc.perform(post("/api/reservations/{id}/complete", id))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("시간을 변경하면 소요시간은 유지된 채 옮겨진다")
    void reschedule() throws Exception {
        long id = book(perm, "2026-10-01T10:00:00+09:00");  // 10:00~12:00

        mockMvc.perform(patch("/api/reservations/{id}/time", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startAt\":\"2026-10-01T11:00:00+09:00\"}"))  // 자기 자신과는 겹쳐도 된다
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.startAt").value("2026-10-01T11:00:00+09:00"))
                .andExpect(jsonPath("$.endAt").value("2026-10-01T13:00:00+09:00"));
    }

    @Test
    @DisplayName("다른 예약과 겹치는 시간으로는 변경할 수 없다 (409)")
    void rescheduleOverlapRejected() throws Exception {
        book(cut, "2026-10-01T14:00:00+09:00");
        long id = book(cut, "2026-10-01T10:00:00+09:00");

        mockMvc.perform(patch("/api/reservations/{id}/time", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startAt\":\"2026-10-01T14:30:00+09:00\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("판매 중지된 메뉴로는 예약할 수 없다 (400)")
    void inactiveMenuRejected() throws Exception {
        cut.deactivate();

        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(cut.getId(), "2026-10-01T14:00:00+09:00")))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("없는 고객으로는 예약할 수 없다 (404)")
    void unknownCustomer() throws Exception {
        mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"customerId":999999,"menuId":%d,"startAt":"2026-10-01T14:00:00+09:00"}
                                """.formatted(cut.getId())))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("기간 조회는 서울 기준 날짜로 자르고 시간순으로 정렬한다")
    void findBetween() throws Exception {
        book(cut, "2026-10-01T15:00:00+09:00");
        book(cut, "2026-10-01T09:00:00+09:00");
        book(cut, "2026-10-01T23:30:00+09:00");  // 서울 기준 10/1 (UTC로는 10/1 14:30)
        book(cut, "2026-10-02T00:30:00+09:00");  // 서울 기준 10/2 (UTC로는 10/1 15:30 — UTC로 자르면 10/1로 잘못 들어간다)
        book(cut, "2026-10-03T10:00:00+09:00");

        mockMvc.perform(get("/api/reservations").param("from", "2026-10-01").param("to", "2026-10-01"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[0].startAt").value("2026-10-01T09:00:00+09:00"))
                .andExpect(jsonPath("$[2].startAt").value("2026-10-01T23:30:00+09:00"));

        mockMvc.perform(get("/api/reservations").param("from", "2026-10-01").param("to", "2026-10-02"))
                .andExpect(jsonPath("$", hasSize(4)));
    }

    @Test
    @DisplayName("서비스 확인을 우회해도 DB 제약이 겹치는 예약을 막는다 (동시 요청 방어선)")
    void databaseConstraintIsLastDefense() {
        Instant start = Instant.parse("2026-10-01T05:00:00Z");
        reservationRepository.saveAndFlush(new Reservation(customer, cut, start, null));

        // 서비스의 사전 확인 없이 저장소에 바로 저장 = 동시에 들어온 두 번째 요청을 흉내 낸다.
        Reservation overlapping = new Reservation(customer, cut, start.plusSeconds(30 * 60), null);
        assertThatThrownBy(() -> reservationRepository.saveAndFlush(overlapping))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    /** API로 예약을 만들고 id를 돌려준다. */
    private long book(TreatmentMenu menu, String startAt) throws Exception {
        String body = mockMvc.perform(post("/api/reservations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reservationJson(menu.getId(), startAt)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+).*", "$1"));
    }

    private String reservationJson(Long menuId, String startAt) {
        return """
                {"customerId":%d,"menuId":%d,"startAt":"%s","memo":"첫 방문"}
                """.formatted(customer.getId(), menuId, startAt);
    }
}
