package com.salonapp.staff;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 직원 테이블(V6 마이그레이션)과 엔티티 매핑이 실제 PostgreSQL에서 맞는지 확인한다. (ADR 0010)
 * 테스트마다 롤백되므로, 마이그레이션이 넣은 기본 직원 "원장" 1명에서 항상 시작한다.
 *
 * saveAndFlush: JPA는 저장을 모아 두었다가 나중에 한꺼번에 DB로 보낸다(flush).
 * DB 제약 위반을 테스트 안에서 바로 확인하려면 그 자리에서 DB로 보내야 해서 flush를 쓴다.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@Transactional
class StaffRepositoryTest {

    @Autowired
    StaffRepository staffRepository;

    @Autowired
    EntityManager entityManager;

    @Test
    @DisplayName("마이그레이션 직후에는 직책이 원장인 직원 1명(원장)이 있다")
    void defaultStaffExists() {
        List<Staff> all = staffRepository.findAllByOrderByIdAsc();

        assertThat(all).hasSize(1);
        Staff director = all.get(0);
        assertThat(director.getName()).isEqualTo("원장");
        assertThat(director.getPosition()).isEqualTo("원장");
        assertThat(director.isActive()).isTrue();
    }

    @Test
    @DisplayName("새로 만든 직원은 근무 중이며, 생성·수정 시각이 채워진다")
    void newStaffDefaults() {
        Staff saved = staffRepository.saveAndFlush(new Staff("  김하나 ", " 디자이너 "));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getName()).isEqualTo("김하나");       // 앞뒤 공백은 잘린다
        assertThat(saved.getPosition()).isEqualTo("디자이너");
        assertThat(saved.isActive()).isTrue();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("이름과 직책이 같은 직원도 직원 번호가 달라 둘 다 등록된다")
    void sameNameAndPositionAllowed() {
        Staff first = staffRepository.saveAndFlush(new Staff("이지수", "실장"));
        Staff second = staffRepository.saveAndFlush(new Staff("이지수", "실장"));

        assertThat(first.getId()).isNotEqualTo(second.getId());
        assertThat(staffRepository.findAllByOrderByIdAsc()).hasSize(3); // 원장 + 둘
    }

    @Test
    @DisplayName("직책이 원장인 직원은 여러 명일 수 있다 (원장은 직책이지 한 명뿐인 신분이 아니다)")
    void severalDirectorsAllowed() {
        staffRepository.saveAndFlush(new Staff("이지수", "원장"));
        staffRepository.saveAndFlush(new Staff("박민수", "원장"));

        assertThat(staffRepository.findAllByOrderByIdAsc()).extracting(Staff::getPosition)
                .containsExactly("원장", "원장", "원장");
    }

    @Test
    @DisplayName("staff 테이블에 owner 컬럼이 없다 (마이그레이션 V8)")
    void ownerColumnWasDropped() {
        @SuppressWarnings("unchecked")
        List<String> columns = entityManager.createNativeQuery(
                "SELECT column_name FROM information_schema.columns WHERE table_name = 'staff'")
                .getResultList();

        assertThat(columns).contains("id", "name", "position", "active").doesNotContain("owner");
    }

    @Test
    @DisplayName("근무 중인 직원만 조회하면 근무를 마친 직원은 빠지고, 번호순으로 나온다")
    void activeOnlyOrderedById() {
        Staff left = staffRepository.saveAndFlush(new Staff("박민수", "디자이너"));
        Staff stays = staffRepository.saveAndFlush(new Staff("김하나", "디자이너"));
        left.deactivate();
        staffRepository.saveAndFlush(left);

        List<Staff> active = staffRepository.findAllByActiveTrueOrderByIdAsc();

        assertThat(active).extracting(Staff::getName).containsExactly("원장", "김하나");
        assertThat(active.get(1).getId()).isEqualTo(stays.getId());
        assertThat(staffRepository.findAllByOrderByIdAsc()).hasSize(3); // 전체에는 남아 있다
    }

    @Test
    @DisplayName("이름이나 직책이 비어 있으면 엔티티가 거부한다")
    void blankRejected() {
        assertThatThrownBy(() -> new Staff(" ", "디자이너")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new Staff("김하나", "")).isInstanceOf(IllegalArgumentException.class);
    }
}
