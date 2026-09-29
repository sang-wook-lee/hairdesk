package com.salonapp.menu.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 시술 메뉴.
 *
 * - setter를 열지 않는다. 값 변경은 update / activate / deactivate 같은
 *   "의도가 드러나는 메서드"로만 한다.
 * - 기본 생성자는 JPA 전용(protected). 코드에서는 public 생성자만 쓴다.
 */
@Entity
@Table(name = "treatment_menu")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TreatmentMenu extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MenuCategory category;

    @Column(nullable = false)
    private int price;

    @Column(name = "duration_minutes", nullable = false)
    private int durationMinutes;

    @Column(nullable = false)
    private boolean active;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    public TreatmentMenu(String name, MenuCategory category, int price, int durationMinutes, int displayOrder) {
        this.active = true;
        update(name, category, price, durationMinutes, displayOrder);
    }

    public void update(String name, MenuCategory category, int price, int durationMinutes, int displayOrder) {
        // 요청 DTO에서도 검증하지만, 엔티티는 어디서 호출되든 스스로 잘못된 상태가 되지 않게 지킨다.
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("메뉴 이름은 필수입니다.");
        }
        if (category == null) {
            throw new IllegalArgumentException("카테고리는 필수입니다.");
        }
        if (price < 0) {
            throw new IllegalArgumentException("가격은 0원 이상이어야 합니다.");
        }
        if (durationMinutes <= 0) {
            throw new IllegalArgumentException("소요 시간은 1분 이상이어야 합니다.");
        }
        this.name = name.strip();
        this.category = category;
        this.price = price;
        this.durationMinutes = durationMinutes;
        this.displayOrder = displayOrder;
    }

    /** 판매 중지. 과거 매출 기록 보존을 위해 삭제 대신 사용한다. */
    public void deactivate() {
        this.active = false;
    }

    public void activate() {
        this.active = true;
    }
}
