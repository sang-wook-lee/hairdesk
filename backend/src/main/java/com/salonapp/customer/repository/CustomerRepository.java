package com.salonapp.customer.repository;

import com.salonapp.customer.domain.Customer;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerRepository extends JpaRepository<Customer, Long> {

    boolean existsByNameAndPhone(String name, String phone);

    // 수정할 때: "나 자신"은 빼고 중복인지 본다.
    boolean existsByNameAndPhoneAndIdNot(String name, String phone, Long id);

    // WHERE name LIKE '%name%'
    Page<Customer> findByNameContaining(String name, Pageable pageable);

    // WHERE name LIKE '%name%' OR phone LIKE '%phone%'
    Page<Customer> findByNameContainingOrPhoneContaining(String name, String phone, Pageable pageable);
}
