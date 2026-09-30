package com.salonapp.reservation.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import com.salonapp.customer.domain.Customer;
import com.salonapp.menu.domain.TreatmentMenu;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Duration;
import java.time.Instant;

/**
 * 예약. 겹침 방지 규칙은 ADR 0003 참고.
 *
 * 상태 변경 규칙(BOOKED에서만 바꿀 수 있다)을 이 엔티티가 스스로 지킨다.
 */
@Entity
@Table(name = "reservation")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Reservation extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // LAZY: 예약만 조회할 때 고객/메뉴 쿼리가 불필요하게 나가지 않게 한다.
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "menu_id")
    private TreatmentMenu menu;

    @Column(name = "start_at", nullable = false)
    private Instant startAt;

    @Column(name = "end_at", nullable = false)
    private Instant endAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ReservationStatus status;

    @Column(length = 500)
    private String memo;

    /** 종료 시각은 시작 시각 + 메뉴 소요시간으로 여기서 계산한다. */
    public Reservation(Customer customer, TreatmentMenu menu, Instant startAt, String memo) {
        if (startAt == null) {
            throw new IllegalArgumentException("예약 시작 시각은 필수입니다.");
        }
        this.customer = customer;
        this.menu = menu;
        this.startAt = startAt;
        this.endAt = startAt.plus(Duration.ofMinutes(menu.getDurationMinutes()));
        this.status = ReservationStatus.BOOKED;
        this.memo = (memo == null || memo.isBlank()) ? null : memo.strip();
    }

    /** 시작 시각을 옮긴다. 소요시간은 그대로라 종료 시각도 같이 움직인다. */
    public void reschedule(Instant newStartAt) {
        requireBooked("시간을 바꿀");
        if (newStartAt == null) {
            throw new IllegalArgumentException("예약 시작 시각은 필수입니다.");
        }
        Duration length = Duration.between(startAt, endAt);
        this.startAt = newStartAt;
        this.endAt = newStartAt.plus(length);
    }

    public void complete() {
        requireBooked("완료 처리할");
        this.status = ReservationStatus.COMPLETED;
    }

    public void cancel() {
        requireBooked("취소할");
        this.status = ReservationStatus.CANCELLED;
    }

    public void markNoShow() {
        requireBooked("노쇼 처리할");
        this.status = ReservationStatus.NO_SHOW;
    }

    private void requireBooked(String action) {
        if (status != ReservationStatus.BOOKED) {
            throw new IllegalStateException("예약됨 상태에서만 " + action + " 수 있습니다. 현재 상태: " + status);
        }
    }
}
