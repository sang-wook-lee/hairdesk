package com.salonapp.menu.dto;

import com.salonapp.menu.domain.MenuCategory;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 메뉴 등록/수정 요청. 등록과 수정의 입력값이 같아서 하나로 쓴다.
 * 여기서 걸러지면 400 응답과 함께 어떤 필드가 왜 틀렸는지 알려준다.
 */
public record MenuRequest(
        @NotBlank @Size(max = 50) String name,
        @NotNull MenuCategory category,
        @NotNull @Min(0) Integer price,
        @NotNull @Min(1) @Max(720) Integer durationMinutes,  // 최대 12시간
        @NotNull @Min(0) Integer displayOrder
) {
}
