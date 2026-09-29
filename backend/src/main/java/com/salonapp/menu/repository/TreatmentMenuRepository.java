package com.salonapp.menu.repository;

import com.salonapp.menu.domain.TreatmentMenu;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TreatmentMenuRepository extends JpaRepository<TreatmentMenu, Long> {

    // 메서드 이름으로 쿼리가 만들어진다:
    // SELECT * FROM treatment_menu ORDER BY display_order ASC, id ASC
    List<TreatmentMenu> findAllByOrderByDisplayOrderAscIdAsc();

    // ... WHERE active = true ORDER BY display_order ASC, id ASC
    List<TreatmentMenu> findAllByActiveTrueOrderByDisplayOrderAscIdAsc();
}
