package com.salonapp.sales.dto;

import com.salonapp.sales.domain.PaymentMethod;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/**
 * 매출 등록 요청. 두 가지 방식으로 쓴다.
 *
 *  1) 예약 건:  { "reservationId": 5, "paymentMethod": "CARD" }
 *               고객/메뉴는 예약에서 가져온다. customerId/menuId는 보내지 않는다.
 *  2) 워크인:   { "customerId": 1, "menuId": 2, "paymentMethod": "CASH" }
 *
 * amount를 생략하면 메뉴 정가, paidAt을 생략하면 지금.
 * 숫자를 int가 아닌 Integer로 받는 이유: "생략(null)"과 "0원"을 구분하기 위해서.
 * (값이 없을 때 int는 0이 되어 버려서 "무료"와 "안 보냄"을 구별할 수 없다)
 *
 * "예약이면 reservationId, 아니면 customerId+menuId"라는 조합 규칙은
 * 어노테이션으로 표현하기 어려워서 SaleService가 검사한다.
 */
public record SaleRequest(
        Long reservationId,
        Long customerId,
        Long menuId,
        @PositiveOrZero Integer amount,
        @NotNull PaymentMethod paymentMethod,
        OffsetDateTime paidAt,
        @Size(max = 500) String memo
) {
}
