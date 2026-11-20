package com.salonapp.staff.dto;

import com.salonapp.staff.domain.Staff;

/** 직원 응답. id가 직원 번호다. 이름·직책이 같은 직원이 있을 수 있어 화면은 번호와 함께 보여준다. */
public record StaffResponse(
        Long id,
        String name,
        String position,
        boolean active
) {
    public static StaffResponse from(Staff staff) {
        return new StaffResponse(
                staff.getId(),
                staff.getName(),
                staff.getPosition(),
                staff.isActive()
        );
    }
}
