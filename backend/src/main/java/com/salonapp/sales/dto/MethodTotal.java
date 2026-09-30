package com.salonapp.sales.dto;

import com.salonapp.sales.domain.PaymentMethod;

/**
 * 결제수단별 합계 한 줄. SaleRepository의 집계 쿼리 결과를 담는다.
 * 합계는 int 범위(약 21억)를 넘을 수 있어 long으로 받는다.
 */
public record MethodTotal(PaymentMethod method, long totalAmount, long count) {
}
