package com.salonapp.menu.dto;

import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;

/** 메뉴 응답. 엔티티를 그대로 내보내지 않고, 보여줄 필드만 골라 담는다. */
public record MenuResponse(
        Long id,
        String name,
        MenuCategory category,
        int price,
        int durationMinutes,
        boolean active,
        int displayOrder
) {
    public static MenuResponse from(TreatmentMenu menu) {
        return new MenuResponse(
                menu.getId(),
                menu.getName(),
                menu.getCategory(),
                menu.getPrice(),
                menu.getDurationMinutes(),
                menu.isActive(),
                menu.getDisplayOrder()
        );
    }
}
