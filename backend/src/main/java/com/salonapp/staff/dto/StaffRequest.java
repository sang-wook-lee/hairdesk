package com.salonapp.staff.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 직원 등록/수정 요청. 등록과 수정의 입력값이 같아서 하나로 쓴다.
 * 주인 여부(owner)와 근무 여부(active)는 여기서 받지 않는다.
 * 각각 make-owner, deactivate/activate 요청으로만 바꾼다. (ADR 0010)
 */
public record StaffRequest(
        @NotBlank @Size(max = 30) String name,
        @NotBlank @Size(max = 30) String position
) {
}
