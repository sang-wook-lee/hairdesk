package com.salonapp.sales.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import com.salonapp.customer.domain.Customer;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.staff.domain.Staff;
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

    /**
     * 이 결제의 담당자. (ADR 0010, V7)
     * 예약 결제는 예약의 담당자를 따르고, 워크인은 직접 정한다.
     * 이름은 복사하지 않고 연결만 한다. 직원 이름을 고치면 과거 매출에도 새 이름이 보인다.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "staff_id")
    private Staff staff;

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

    /** 예약 건의 매출. 고객·메뉴·담당자는 예약에서 그대로 가져온다. amount가 null이면 정가를 받은 것으로 본다. */
    public static Sale forReservation(Reservation reservation, Integer amount,
                                      PaymentMethod method, Instant paidAt, String memo) {
        Sale sale = new Sale();
        sale.reservation = reservation;
        sale.fill(reservation.getCustomer(), reservation.getMenu(), reservation.getStaff(), amount, method, paidAt, memo);
        return sale;
    }

    /**
     * 예약 없이 온 손님의 매출.
     * 근무를 마친 직원도 담당자로 기록할 수 있다. 매출은 이미 끝난 시술을 적는 것이기 때문이다.
     * (판매 중지 메뉴로도 매출을 받을 수 있게 둔 것과 같은 이유)
     */
    public static Sale walkIn(Customer customer, TreatmentMenu menu, Staff staff, Integer amount,
                              PaymentMethod method, Instant paidAt, String memo) {
        Sale sale = new Sale();
        sale.fill(customer, menu, staff, amount, method, paidAt, memo);
        return sale;
    }

    private void fill(Customer customer, TreatmentMenu menu, Staff staff, Integer amount,
                      PaymentMethod method, Instant paidAt, String memo) {
        if (staff == null) {
            throw new IllegalArgumentException("담당자는 필수입니다.");
        }
        this.customer = customer;
        this.menu = menu;
        this.staff = staff;
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
