package com.salonapp.sales.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import com.salonapp.customer.domain.Customer;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.reservation.domain.Reservation;
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

import java.time.Instant;

/**
 * 매출 한 건. 정책은 ADR 0004 참고.
 *
 * 만드는 방법이 두 가지(예약 기반 / 워크인)라서 public 생성자 대신 이름이 있는 팩토리 메서드를 쓴다.
 * "new Sale(...)"보다 "Sale.forReservation(...)"이 무슨 상황인지 바로 읽힌다.
 */
@Entity
@Table(name = "sale")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Sale extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 워크인이면 null */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reservation_id")
    private Reservation reservation;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "menu_id")
    private TreatmentMenu menu;

    /** 결제 시점 메뉴 이름 (스냅샷) */
    @Column(name = "menu_name", nullable = false, length = 50)
    private String menuName;

    /** 결제 시점 정가 (스냅샷) */
    @Column(nullable = false)
    private int price;

    /** 실제 받은 금액 */
    @Column(nullable = false)
    private int amount;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method", nullable = false, length = 20)
    private PaymentMethod paymentMethod;

    @Column(name = "paid_at", nullable = false)
    private Instant paidAt;

    @Column(length = 500)
    private String memo;

    /** 예약 건의 매출. 고객과 메뉴는 예약에서 그대로 가져온다. amount가 null이면 정가를 받은 것으로 본다. */
    public static Sale forReservation(Reservation reservation, Integer amount,
                                      PaymentMethod method, Instant paidAt, String memo) {
        Sale sale = new Sale();
        sale.reservation = reservation;
        sale.fill(reservation.getCustomer(), reservation.getMenu(), amount, method, paidAt, memo);
        return sale;
    }

    /** 예약 없이 온 손님의 매출 */
    public static Sale walkIn(Customer customer, TreatmentMenu menu, Integer amount,
                              PaymentMethod method, Instant paidAt, String memo) {
        Sale sale = new Sale();
        sale.fill(customer, menu, amount, method, paidAt, memo);
        return sale;
    }

    private void fill(Customer customer, TreatmentMenu menu, Integer amount,
                      PaymentMethod method, Instant paidAt, String memo) {
        this.customer = customer;
        this.menu = menu;
        this.menuName = menu.getName();
        this.price = menu.getPrice();
        correct(amount == null ? menu.getPrice() : amount, method, paidAt, memo);
    }

    /**
     * 금액/수단/결제시각/메모를 고친다. (입력 실수 정정용. 고객·메뉴·정가는 바꾸지 않는다)
     * 처음 만들 때도 같은 검증을 쓰려고 생성 경로에서도 이 메서드를 거친다.
     */
    public void correct(int amount, PaymentMethod method, Instant paidAt, String memo) {
        if (amount < 0) {
            throw new IllegalArgumentException("결제 금액은 0원 이상이어야 합니다.");
        }
        if (method == null) {
            throw new IllegalArgumentException("결제 수단은 필수입니다.");
        }
        if (paidAt == null) {
            throw new IllegalArgumentException("결제 시각은 필수입니다.");
        }
        this.amount = amount;
        this.paymentMethod = method;
        this.paidAt = paidAt;
        this.memo = (memo == null || memo.isBlank()) ? null : memo.strip();
    }

    /** 할인액 = 정가 - 받은 금액. 덤으로 더 받았다면 음수. */
    public int getDiscount() {
        return price - amount;
    }
}
