package com.salonapp.staff.repository;

import com.salonapp.staff.domain.Staff;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface StaffRepository extends JpaRepository<Staff, Long> {

    // 직원 번호(id) 순서. 이름이 같은 직원이 있어도 순서가 항상 같다.
    List<Staff> findAllByOrderByIdAsc();

    // ... WHERE active = true ORDER BY id ASC
    List<Staff> findAllByActiveTrueOrderByIdAsc();
}
