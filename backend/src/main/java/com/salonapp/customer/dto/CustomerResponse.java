package com.salonapp.customer.dto;

import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.domain.Gender;

import java.time.Instant;

public record CustomerResponse(
        Long id,
        String name,
        String phone,        // 숫자만 (01012345678). 하이픈 표시는 화면에서.
        Gender gender,
        String memo,
        boolean smsConsent,
        Instant createdAt    // 첫 등록일 = 첫 방문일에 가깝다. 신규/재방문 통계에 쓸 예정.
) {
    public static CustomerResponse from(Customer customer) {
        return new CustomerResponse(
                customer.getId(),
                customer.getName(),
                customer.getPhone(),
                customer.getGender(),
                customer.getMemo(),
                customer.isSmsConsent(),
                customer.getCreatedAt()
        );
    }
}
