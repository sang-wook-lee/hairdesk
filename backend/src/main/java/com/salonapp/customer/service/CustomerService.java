package com.salonapp.customer.service;

import com.salonapp.common.dto.PageResponse;
import com.salonapp.common.exception.ConflictException;
import com.salonapp.common.exception.NotFoundException;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.dto.CustomerRequest;
import com.salonapp.customer.dto.CustomerResponse;
import com.salonapp.customer.repository.CustomerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CustomerService {

    private final CustomerRepository customerRepository;

    @Transactional
    public CustomerResponse create(CustomerRequest request) {
        String name = request.name().strip();
        String phone = Customer.normalizePhone(request.phone());
        // 먼저 확인해서 친절한 메시지로 409를 준다.
        // 동시에 들어온 요청이 둘 다 여길 통과해도 DB의 UNIQUE 제약이 최종적으로 막는다.
        if (customerRepository.existsByNameAndPhone(name, phone)) {
            throw new ConflictException("이미 등록된 고객입니다: " + name);
        }
        Customer customer = new Customer(name, phone, request.gender(), request.memo(), request.smsConsent());
        return CustomerResponse.from(customerRepository.save(customer));
    }

    /**
     * 키워드로 검색. 이름 일부("김") 또는 번호 일부("5678", "010-1234")로 찾는다.
     * 키워드가 비어 있으면 전체 목록.
     */
    public PageResponse<CustomerResponse> search(String keyword, Pageable pageable) {
        String trimmed = keyword == null ? "" : keyword.strip();
        String digits = trimmed.replaceAll("\\D", "");

        Page<Customer> customers;
        if (trimmed.isEmpty()) {
            customers = customerRepository.findAll(pageable);
        } else if (digits.isEmpty()) {
            // 숫자가 없으면 번호 조건을 빼야 한다. phone LIKE '%%'는 모든 행과 일치해 버리기 때문.
            customers = customerRepository.findByNameContaining(trimmed, pageable);
        } else {
            customers = customerRepository.findByNameContainingOrPhoneContaining(trimmed, digits, pageable);
        }
        return PageResponse.from(customers.map(CustomerResponse::from));
    }

    public CustomerResponse findById(Long id) {
        return CustomerResponse.from(getCustomer(id));
    }

    @Transactional
    public CustomerResponse update(Long id, CustomerRequest request) {
        Customer customer = getCustomer(id);
        String name = request.name().strip();
        String phone = Customer.normalizePhone(request.phone());
        if (customerRepository.existsByNameAndPhoneAndIdNot(name, phone, id)) {
            throw new ConflictException("같은 이름과 번호의 고객이 이미 있습니다: " + name);
        }
        customer.update(name, phone, request.gender(), request.memo(), request.smsConsent());
        return CustomerResponse.from(customer);
    }

    private Customer getCustomer(Long id) {
        return customerRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("고객을 찾을 수 없습니다. id=" + id));
    }
}
