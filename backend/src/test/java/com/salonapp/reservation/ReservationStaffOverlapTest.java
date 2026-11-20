package com.salonapp.reservation;

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
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 예약 겹침 규칙이 "같은 직원끼리만"으로 바뀐 것을 DB 제약 수준에서 확인한다. (ADR 0010 7·8번, V7)
 *
 * 서비스의 사전 확인을 거치지 않고 저장소에 바로 저장한다. 서비스가 놓친 동시 요청을
 * 마지막에 막아 주는 것이 이 제약이기 때문이다. (ADR 0003)
 *
 * "같은 직원이면 거부"와 "다른 직원이면 허용"을 둘 다 확인해야 제약이 직원 기준임이 증명된다.
 * 제약이 아예 없으면 앞의 테스트가, 예전처럼 전체 기준이면 뒤의 테스트가 실패한다.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@Transactional
class ReservationStaffOverlapTest {

    @Autowired ReservationRepository reservationRepository;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired StaffRepository staffRepository;
    @Autowired EntityManager entityManager;

    Staff owner;     // 마이그레이션이 만든 기본 직원(원장)
    Staff designer;  // 두 번째 직원
    Customer mother;
    Customer child;
    TreatmentMenu cut;  // 60분

    // 14:00~15:00 (서울) = 05:00Z~06:00Z
    static final Instant START = Instant.parse("2026-10-01T05:00:00Z");

    @BeforeEach
    void setUp() {
        owner = staffRepository.findByOwnerTrue().orElseThrow();
        designer = staffRepository.save(new Staff("이지수", "디자이너"));
        mother = customerRepository.save(new Customer("김어머니", "01011112222", null, null, false));
        child = customerRepository.save(new Customer("김자녀", "01011112222", null, null, false)); // 번호를 같이 쓰는 가족
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
    }

    @Test
    @DisplayName("같은 직원의 시간이 겹치는 예약은 DB가 거부한다")
    void sameStaffOverlapRejected() {
        reservationRepository.saveAndFlush(new Reservation(mother, cut, owner, START, null));

        Reservation overlapping = new Reservation(child, cut, owner, START.plusSeconds(30 * 60), null);
        assertThatThrownBy(() -> reservationRepository.saveAndFlush(overlapping))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("다른 직원이면 같은 시간에도 예약할 수 있다")
    void differentStaffSameTimeAllowed() {
        reservationRepository.saveAndFlush(new Reservation(mother, cut, owner, START, null));
        reservationRepository.saveAndFlush(new Reservation(child, cut, designer, START, null));

        assertThat(reservationRepository.findAll()).hasSize(2);
    }

    @Test
    @DisplayName("같은 고객이 같은 시간에 서로 다른 직원에게 예약할 수 있다 (가족과 함께 오는 경우)")
    void sameCustomerTwoStaffSameTimeAllowed() {
        reservationRepository.saveAndFlush(new Reservation(mother, cut, owner, START, null));
        reservationRepository.saveAndFlush(new Reservation(mother, cut, designer, START, null));

        List<Reservation> all = reservationRepository.findAll();
        assertThat(all).hasSize(2);
        assertThat(all).extracting(r -> r.getCustomer().getId()).containsOnly(mother.getId());
    }

    @Test
    @DisplayName("같은 직원이라도 앞 예약이 끝나는 시각에 다음 예약이 시작하면 겹치지 않는다")
    void backToBackAllowed() {
        reservationRepository.saveAndFlush(new Reservation(mother, cut, owner, START, null));
        // 15:00 시작 = 앞 예약(14:00~15:00)이 끝나는 시각. 구간은 [시작, 끝)이라 맞닿는 것은 허용.
        reservationRepository.saveAndFlush(new Reservation(child, cut, owner, START.plusSeconds(60 * 60), null));

        assertThat(reservationRepository.findAll()).hasSize(2);
    }

    @Test
    @DisplayName("취소된 예약은 자리를 차지하지 않아 같은 직원이 같은 시간에 다시 받을 수 있다")
    void cancelledFreesSlot() {
        Reservation first = reservationRepository.saveAndFlush(new Reservation(mother, cut, owner, START, null));
        first.cancel();
        reservationRepository.saveAndFlush(first);

        reservationRepository.saveAndFlush(new Reservation(child, cut, owner, START, null));

        assertThat(reservationRepository.findAll()).hasSize(2);
    }

    @Test
    @DisplayName("근무를 마친 직원에게는 새 예약을 만들 수 없고, 예전 예약은 그대로 남는다")
    void inactiveStaffCannotTakeNewReservation() {
        reservationRepository.saveAndFlush(new Reservation(mother, cut, designer, START, null));
        designer.deactivate();
        staffRepository.saveAndFlush(designer);

        assertThatThrownBy(() -> new Reservation(child, cut, designer, START.plusSeconds(3 * 60 * 60), null))
                .isInstanceOf(IllegalStateException.class);
        assertThat(reservationRepository.findAll()).hasSize(1);
    }

    @Test
    @DisplayName("담당자 없이는 예약을 만들 수 없다")
    void staffRequired() {
        assertThatThrownBy(() -> new Reservation(mother, cut, null, START, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("옛 전체 기준 제약은 없어지고 직원별 제약만 남아 있다 (마이그레이션 V7)")
    void constraintWasReplaced() {
        @SuppressWarnings("unchecked")
        List<String> names = entityManager.createNativeQuery(
                "SELECT conname FROM pg_constraint WHERE conrelid = 'reservation'::regclass AND contype = 'x'")
                .getResultList();

        assertThat(names).containsExactly("ex_reservation_no_overlap_per_staff");
    }
}
