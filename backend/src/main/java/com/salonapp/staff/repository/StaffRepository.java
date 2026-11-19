package com.salonapp.staff.repository;

import com.salonapp.staff.domain.Staff;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface StaffRepository extends JpaRepository<Staff, Long> {

    // 직원 번호(id) 순서. 이름이 같은 직원이 있어도 순서가 항상 같다.
    List<Staff> findAllByOrderByIdAsc();

    // ... WHERE active = true ORDER BY id ASC
    List<Staff> findAllByActiveTrueOrderByIdAsc();

    // ... WHERE owner = true  (주인은 DB 제약으로 최대 1명이라 결과가 하나뿐이다)
    Optional<Staff> findByOwnerTrue();
}
