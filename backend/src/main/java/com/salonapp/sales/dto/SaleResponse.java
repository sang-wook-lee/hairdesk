package com.salonapp.sales.dto;

import com.salonapp.common.time.SeoulDates;
import com.salonapp.sales.domain.PaymentMethod;
import com.salonapp.sales.domain.Sale;

import java.time.OffsetDateTime;

public record SaleResponse(
        Long id,
        Long reservationId,      // 워크인이면 null
        Long customerId,
        String customerName,
        Long menuId,
        String menuName,         // 결제 당시 이름
        int price,               // 결제 당시 정가
        int amount,              // 실제 받은 금액
        int discount,            // price - amount
        PaymentMethod paymentMethod,
        OffsetDateTime paidAt,   // +09:00 (Asia/Seoul)
        String memo
) {
    public static SaleResponse from(Sale sale) {
        return new SaleResponse(
                sale.getId(),
                // reservation은 LAZY라 객체를 만지면 쿼리가 나간다. id만 필요하므로 참조 자체가 null인지만 본다.
                sale.getReservation() == null ? null : sale.getReservation().getId(),
                sale.getCustomer().getId(),
                sale.getCustomer().getName(),
                sale.getMenu().getId(),
                sale.getMenuName(),
                sale.getPrice(),
                sale.getAmount(),
                sale.getDiscount(),
                sale.getPaymentMethod(),
                sale.getPaidAt().atZone(SeoulDates.SEOUL).toOffsetDateTime(),
                sale.getMemo()
        );
    }
}
