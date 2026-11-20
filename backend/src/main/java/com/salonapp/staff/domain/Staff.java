package com.salonapp.staff.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 직원(담당자). ADR 0010, 0011
 *
 * - 직원은 id(= 직원 번호)로 구분한다. 이름·직책이 같은 직원이 있을 수 있다.
 * - "주인" 같은 특별한 직원은 없다. 총책임자는 직책("원장")으로 표현하고, 모든 직원은 같은 규칙을 따른다. (ADR 0011)
 * - 근무를 마친 직원은 삭제하지 않고 active=false로 둔다. 과거 예약·매출이 이 직원을 참조하기 때문이다.
 */
@Entity
@Table(name = "staff")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Staff extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 30)
    private String name;

    /** 직책(원장, 실장, 디자이너 ...). 자유 입력이지만 비울 수는 없다. */
    @Column(nullable = false, length = 30)
    private String position;

    @Column(nullable = false)
    private boolean active;

    public Staff(String name, String position) {
        this.active = true;
        update(name, position);
    }

    public void update(String name, String position) {
        // 요청 DTO에서도 검증하지만, 엔티티는 어디서 호출되든 스스로 잘못된 상태가 되지 않게 지킨다.
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("직원 이름은 필수입니다.");
        }
        if (position == null || position.isBlank()) {
            throw new IllegalArgumentException("직책은 필수입니다.");
        }
        this.name = name.strip();
        this.position = position.strip();
    }

    /** 근무 종료. 과거 예약·매출 기록 보존을 위해 삭제 대신 사용한다. */
    public void deactivate() {
        this.active = false;
    }

    public void activate() {
        this.active = true;
    }
}
