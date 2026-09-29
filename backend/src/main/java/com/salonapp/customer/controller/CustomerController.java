package com.salonapp.customer.controller;

import com.salonapp.common.dto.PageResponse;
import com.salonapp.customer.dto.CustomerRequest;
import com.salonapp.customer.dto.CustomerResponse;
import com.salonapp.customer.service.CustomerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 고객 카드 API.
 *
 * POST /api/customers                        등록 → 201 (이름+번호 중복이면 409)
 * GET  /api/customers?keyword=5678&page=0    검색 (이름 또는 번호 일부), 페이징
 * GET  /api/customers/{id}                   단건 조회
 * PUT  /api/customers/{id}                   수정
 *
 * 삭제 API는 아직 없다. 개인정보 파기 정책을 정한 뒤 추가한다. (ADR 0002)
 */
@Tag(name = "고객", description = "고객 카드 (이름, 연락처, 메모)")
@RestController
@RequestMapping("/api/customers")
@RequiredArgsConstructor
public class CustomerController {

    private final CustomerService customerService;

    @Operation(summary = "고객 등록", description = "번호는 하이픈 유무 상관없음. 이름+번호가 같은 고객이 있으면 409")
    @PostMapping
    public ResponseEntity<CustomerResponse> create(@Valid @RequestBody CustomerRequest request) {
        CustomerResponse created = customerService.create(request);
        return ResponseEntity.created(URI.create("/api/customers/" + created.id())).body(created);
    }

    @Operation(summary = "고객 검색", description = "keyword: 이름 일부 또는 번호 일부(뒷자리 4개 등). 비우면 전체. 기본 이름순 20명씩")
    @GetMapping
    public PageResponse<CustomerResponse> search(
            @RequestParam(required = false) String keyword,
            @ParameterObject @PageableDefault(size = 20, sort = "name", direction = Sort.Direction.ASC) Pageable pageable
    ) {
        return customerService.search(keyword, pageable);
    }

    @Operation(summary = "고객 단건 조회")
    @GetMapping("/{id}")
    public CustomerResponse findById(@PathVariable Long id) {
        return customerService.findById(id);
    }

    @Operation(summary = "고객 수정")
    @PutMapping("/{id}")
    public CustomerResponse update(@PathVariable Long id, @Valid @RequestBody CustomerRequest request) {
        return customerService.update(id, request);
    }
}
