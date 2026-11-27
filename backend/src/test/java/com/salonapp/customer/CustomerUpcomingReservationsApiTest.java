package com.salonapp.customer;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.repository.ReservationRepository;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /api/customers/{id}/upcoming-reservations 통합 테스트.
 * 고객 상세의 "다음 예약": 예약됨(BOOKED) 상태인 예약 전부를 시간순으로.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class CustomerUpcomingReservationsApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired StaffRepository staffRepository;

    Staff director;      // V6 마이그레이션이 만든 기본 직원(원장)
    Staff jisoo;
    Customer minji;
    Customer haneul;
    TreatmentMenu cut;
    TreatmentMenu perm;

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
    @DisplayName("예약됨 상태만 나온다. 완료·취소·노쇼는 빠진다")
    void onlyBooked() throws Exception {
        reserve(minji, cut, director, "2026-10-01T01:00:00Z").complete();
        reserve(minji, cut, director, "2026-10-02T01:00:00Z").cancel();
        reserve(minji, cut, director, "2026-10-03T01:00:00Z").markNoShow();
        Reservation booked = reserve(minji, cut, director, "2026-10-04T01:00:00Z");

        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(booked.getId()))
                .andExpect(jsonPath("$[0].status").value("BOOKED"));
    }

    @Test
    @DisplayName("시작 시각이 가까운 순으로 나온다 (저장한 순서가 아니다)")
    void orderedByStartTime() throws Exception {
        reserve(minji, cut, director, "2026-10-20T01:00:00Z");
        reserve(minji, cut, director, "2026-10-05T01:00:00Z");   // 나중에 저장했지만 가장 이르다
        reserve(minji, cut, director, "2026-10-10T01:00:00Z");

        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].startAt").value("2026-10-05T10:00:00+09:00"))
                .andExpect(jsonPath("$[1].startAt").value("2026-10-10T10:00:00+09:00"))
                .andExpect(jsonPath("$[2].startAt").value("2026-10-20T10:00:00+09:00"));
    }

    @Test
    @DisplayName("시각이 지났지만 처리 안 된 예약됨 상태 예약도 나온다")
    void pastButUnprocessedIsIncluded() throws Exception {
        reserve(minji, cut, director, "2020-01-01T01:00:00Z");   // 한참 지난 예약, 아직 예약됨

        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].startAt").value("2020-01-01T10:00:00+09:00"));
    }

    @Test
    @DisplayName("다른 고객의 예약은 섞이지 않는다")
    void doesNotMixCustomers() throws Exception {
        reserve(haneul, perm, jisoo, "2026-10-05T01:00:00Z");
        Reservation mine = reserve(minji, cut, director, "2026-10-06T01:00:00Z");

        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(mine.getId()))
                .andExpect(jsonPath("$[0].customerId").value(minji.getId()));
    }

    @Test
    @DisplayName("예약이 없는 고객은 200과 빈 목록을 준다")
    void noReservationsIsEmpty() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    @DisplayName("없는 고객은 404와 안내 메시지를 준다")
    void unknownCustomerIs404() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", 999999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("고객을 찾을 수 없습니다. id=999999"));
    }

    @Test
    @DisplayName("메뉴 이름과 담당 직원의 번호·이름·직책이 응답에 들어 있다")
    void includesMenuAndStaff() throws Exception {
        reserve(minji, perm, jisoo, "2026-10-05T01:00:00Z");

        mockMvc.perform(get("/api/customers/{id}/upcoming-reservations", minji.getId()))
                .andExpect(jsonPath("$[0].menuName").value("펌"))
                .andExpect(jsonPath("$[0].staffId").value(jisoo.getId()))
                .andExpect(jsonPath("$[0].staffName").value("이지수"))
                .andExpect(jsonPath("$[0].staffPosition").value("실장"));
    }

    // ---- 도우미 ----

    private Instant at(String iso) {
        return OffsetDateTime.parse(iso).toInstant();
    }

    /** 같은 직원의 시간이 겹치지 않게 테스트마다 날짜를 다르게 준다. */
    private Reservation reserve(Customer customer, TreatmentMenu menu, Staff staff, String startAtUtc) {
        return reservationRepository.saveAndFlush(new Reservation(customer, menu, staff, at(startAtUtc), null));
    }
}
