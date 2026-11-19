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
 * 직원(담당자). ADR 0010
 *
 * - 직원은 id(= 직원 번호)로 구분한다. 이름·직책이 같은 직원이 있을 수 있다.
 * - 새로 만든 직원은 항상 주인이 아니다(owner = false). 주인은 마이그레이션이 만든 1명에서
 *   시작하고, 바꿀 때는 아래 markAsOwner / unmarkAsOwner를 한 트랜잭션에서 함께 쓴다.
 * - "주인은 비활성화할 수 없다", "주인이 될 직원은 근무 중이어야 한다" 같은 규칙은
 *   다른 직원(현재 주인)을 알아야 하는 규칙이라 StaffService가 확인한다.
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

    /** 매장 주인 표시. 담당자를 생략했을 때의 기본 담당자. DB가 "true는 최대 1명"을 보장한다. */
    @Column(nullable = false)
    private boolean owner;

    @Column(nullable = false)
    private boolean active;

    public Staff(String name, String position) {
        this.active = true;
        this.owner = false;
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

    public void markAsOwner() {
        this.owner = true;
    }

    public void unmarkAsOwner() {
        this.owner = false;
    }
}
