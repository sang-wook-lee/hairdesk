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
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
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
import java.util.Map;
import java.util.stream.Collectors;

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
    @Autowired StaffRepository staffRepository;
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
    @DisplayName("직원은 4명이고, 원장이 있으며, 근무를 마친 직원이 1명 있다")
    void seedsStaff() {
        List<Staff> staff = staffRepository.findAll();

        assertThat(staff).hasSize(4);
        assertThat(staff).extracting(Staff::getName).contains("원장");
        assertThat(staff).filteredOn(s -> !s.isActive()).extracting(Staff::getName).containsExactly("서하윤");
    }

    @Test
    @Transactional(readOnly = true) // 예약·매출의 담당자는 지연 로딩이라 트랜잭션 안에서만 읽을 수 있다
    @DisplayName("예약은 모든 직원에게 나뉘어 있고, 근무를 마친 직원은 지난 이력만 있다")
    void reservationsSpreadAcrossStaff() {
        List<Reservation> all = reservationRepository.findAll();
        Instant now = Instant.now();

        assertThat(all).extracting(r -> r.getStaff().getName())
                .contains("원장", "이지수", "박민수", "서하윤");
        assertThat(all).filteredOn(r -> !r.getStaff().isActive())
                .isNotEmpty()
                .allMatch(r -> r.getEndAt().isBefore(now));
    }

    @Test
    @Transactional(readOnly = true)
    @DisplayName("같은 시간에 서로 다른 직원의 예약이 함께 있는 때가 있다 (직원별 일정)")
    void sameTimeDifferentStaff() {
        Map<Instant, Long> staffCountByStart = reservationRepository.findAll().stream()
                .collect(Collectors.groupingBy(Reservation::getStartAt,
                        Collectors.mapping(r -> r.getStaff().getId(), Collectors.collectingAndThen(
                                Collectors.toSet(), set -> (long) set.size()))));

        assertThat(staffCountByStart.values()).anyMatch(count -> count >= 2);
    }

    @Test
    @Transactional(readOnly = true)
    @DisplayName("매출의 담당자는 그 예약의 담당자와 같다")
    void saleStaffMatchesReservationStaff() {
        List<Sale> sales = saleRepository.findAll();

        assertThat(sales).isNotEmpty()
                .allMatch(s -> s.getStaff().getId().equals(s.getReservation().getStaff().getId()));
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

        // 단골(전 기간)과 신규(최근 3주부터 등장)가 모두 있어야 한다.
        // 기간은 시더가 신규 고객을 등장시키는 21일에 맞춘다. 14일로 하면 오늘이 화~목일 때 신규가 0명이 되어
        // 실패한다(시더가 일요일을 건너뛰어 난수 순서가 요일마다 달라지기 때문. 요일 7개로 직접 확인함).
        String customers = mockMvc.perform(get("/api/stats/customers")
                        .param("from", today.minusDays(21).toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        assertThat(customers).doesNotContain("\"returningCustomers\":0").doesNotContain("\"newCustomers\":0");

        String daily = mockMvc.perform(get("/api/stats/sales/daily")
                        .param("from", from.toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        assertThat(daily).contains("\"totalAmount\":").containsPattern("\"totalAmount\":[1-9]");

        String reservationStats = mockMvc.perform(get("/api/stats/reservations")
                        .param("from", today.minusDays(60).toString()).param("to", today.toString()))
                .andReturn().getResponse().getContentAsString();
        // 글자로 "0.0"이 없는지 보면 0.068 같은 값도 걸린다. 숫자로 꺼내서 0보다 큰지 본다.
        java.util.regex.Matcher rate = java.util.regex.Pattern.compile("\"noShowRate\":([0-9.Ee-]+)").matcher(reservationStats);
        assertThat(rate.find()).isTrue();
        assertThat(Double.parseDouble(rate.group(1))).isGreaterThan(0.0);
    }
}
