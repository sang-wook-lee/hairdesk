package com.salonapp.sales.dto;

import java.util.List;

/** 기간 매출 요약: 총 매출, 건수, 결제수단별 내역 */
public record SalesSummaryResponse(
        long totalAmount,
        long count,
        List<MethodTotal> byMethod
) {
    public static SalesSummaryResponse from(List<MethodTotal> byMethod) {
        long total = byMethod.stream().mapToLong(MethodTotal::totalAmount).sum();
        long count = byMethod.stream().mapToLong(MethodTotal::count).sum();
        return new SalesSummaryResponse(total, count, byMethod);
    }
}
