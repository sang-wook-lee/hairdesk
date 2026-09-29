package com.salonapp.customer.dto;

import com.salonapp.customer.domain.Gender;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 고객 등록/수정 요청.
 * 번호는 "010-1234-5678"처럼 하이픈이 있어도 되고 없어도 된다. 저장할 때 숫자만 남긴다.
 */
public record CustomerRequest(
        @NotBlank @Size(max = 30) String name,
        @NotBlank @Pattern(regexp = "^01[016789][- ]?\\d{3,4}[- ]?\\d{4}$", message = "올바른 휴대폰 번호가 아닙니다.")
        String phone,
        Gender gender,            // 선택
        @Size(max = 1000) String memo,
        Boolean smsConsent        // 생략하면 false (동의하지 않음)
) {
    /**
     * record의 "compact 생성자": 필드에 값이 들어가기 전에 가공할 수 있다.
     *
     * smsConsent를 boolean(기본형)이 아니라 Boolean으로 받는 이유:
     * Spring Boot 4가 쓰는 Jackson 3는 JSON에 없는 기본형 필드를 false로 채우지 않고
     * 요청 자체를 실패(400)시킨다. 그래서 null을 허용하고, 여기서 false로 바꾼다.
     */
    public CustomerRequest {
        if (smsConsent == null) {
            smsConsent = false;
        }
    }
}
