package com.salonapp.sales.dto;

import com.salonapp.sales.domain.PaymentMethod;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/** 매출 정정 요청. 고객/메뉴/정가는 바꿀 수 없고, 금액·수단·결제시각·메모만 고친다. */
public record SaleUpdateRequest(
        @NotNull @PositiveOrZero Integer amount,
        @NotNull PaymentMethod paymentMethod,
        @NotNull OffsetDateTime paidAt,
        @Size(max = 500) String memo
) {
}
