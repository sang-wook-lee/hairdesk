package com.salonapp.sales.domain;

/** 결제 수단 */
public enum PaymentMethod {
    CASH,      // 현금
    CARD,      // 카드
    TRANSFER,  // 계좌이체
    ETC        // 기타 (상품권, 네이버페이 등)
}
