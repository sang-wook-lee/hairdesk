package com.salonapp.common.dev;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 개발용 샘플 데이터가 "local" 프로필에서 빈 DB에 채워지는지 확인한다.
 * 이 테스트의 컨텍스트는 자기만의 테스트용 DB(Testcontainers)를 쓰므로 다른 테스트와 섞이지 않는다.
 * 서버가 켜지는 순간 시더가 한 번 돌았으므로, 여기서는 그 결과를 검사한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("local")
@Import(TestcontainersConfiguration.class)
class DevDataSeederTest {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    @Autowired DevDataSeeder seeder;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired CustomerRepository customerRepository;
    @Autowired ReservationRepository reservationRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired MockMvc mockMvc;

    @Test
    @DisplayName("빈 DB에 메뉴, 고객, 예약, 매출 샘플이 채워진다 (판매 중지 메뉴 포함)")
    void seedsSampleData() {
        List<TreatmentMenu> menus = menuRepository.findAll();

        assertThat(menus).hasSizeGreaterThanOrEqualTo(7);
        assertThat(menus).anyMatch(m -> !m.isActive());
        assertThat(customerRepository.count()).isEqualTo(12);
        assertThat(reservationRepository.count()).isGreaterThan(50);
        assertThat(saleRepository.count()).isGreaterThan(40);
    }

    @Test
    @DisplayName("지난 예약은 결과(완료/취소/노쇼)가 정해져 있고, 앞으로의 예약은 모두 '예약' 상태다")
    void pastAndFutureStatuses() {
        List<Reservation> all = reservationRepository.findAll();
        Instant now = Instant.now();

        assertThat(all).filteredOn(r -> r.getEndAt().isAfter(now))
                .isNotEmpty()
                .allMatch(r -> r.getStatus() == ReservationStatus.BOOKED);
        assertThat(all).filteredOn(r -> !r.getEndAt().isAfter(now))
                .isNotEmpty()
                .noneMatch(r -> r.getStatus() == ReservationStatus.BOOKED)
                .anyMatch(r -> r.getStatus() == ReservationStatus.CANCELLED)
                .anyMatch(r -> r.getStatus() == ReservationStatus.NO_SHOW);
    }

    @Test
    @Transactional(readOnly = true) // sale.getReservation()은 지연 로딩이라, 트랜잭션 안에서만 읽을 수 있다
    @DisplayName("매출은 완료된 예약에만 있고, 미래 시각의 매출은 없다")
    void salesOnlyForCompletedReservations() {
        Instant now = Instant.now();

        List<Sale> sales = saleRepository.findAll();

        assertThat(sales).isNotEmpty()
                .allMatch(s -> s.getReservation().getStatus() == ReservationStatus.COMPLETED)
                .noneMatch(s -> s.getPaidAt().isAfter(now));
    }

    @Test
    @DisplayName("이미 데이터가 있으면 다시 실행해도 아무것도 추가하지 않는다")
    void doesNotDuplicate() {
        long menus = menuRepository.count();
        long customers = customerRepository.count();
        long reservations = reservationRepository.count();
        long sales = saleRepository.count();

        seeder.run(null); // 서버를 한 번 더 켠 것과 같다

        assertThat(menuRepository.count()).isEqualTo(menus);
        assertThat(customerRepository.count()).isEqualTo(customers);
        assertThat(reservationRepository.count()).isEqualTo(reservations);
        assertThat(saleRepository.count()).isEqualTo(sales);
    }

    @Test
    @DisplayName("통계 화면이 쓸 값이 나온다: 최근 30일 매출, 신규/재방문 고객, 노쇼율")
    void statsHaveValues() throws Exception {
        LocalDate today = LocalDate.now(SEOUL);
        LocalDate from = today.minusDays(30);

        mockMvc.perform(get("/api/stats/sales/daily").param("from", from.toString()).param("to", today.toString()))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/stats/sales/by-menu").param("from", from.toString()).param("to", today.toString()))
                .andExpect(status().isOk());

        // 단골(전 기간)과 신규(최근 3주)가 모두 있어야 한다: 최근 30일 기준으로 재방문과 신규가 모두 0보다 크다
        String customers = mockMvc.perform(get("/api/stats/customers")
                        .param("from", today.minusDays(14).toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        assertThat(customers).doesNotContain("\"returningCustomers\":0").doesNotContain("\"newCustomers\":0");

        String daily = mockMvc.perform(get("/api/stats/sales/daily")
                        .param("from", from.toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        assertThat(daily).contains("\"totalAmount\":").containsPattern("\"totalAmount\":[1-9]");

        String reservationStats = mockMvc.perform(get("/api/stats/reservations")
                        .param("from", today.minusDays(60).toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        assertThat(reservationStats).doesNotContain("\"noShowRate\":0.0");
    }
}
