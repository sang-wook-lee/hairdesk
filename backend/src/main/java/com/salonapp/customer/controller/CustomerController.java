package com.salonapp.customer.controller;

import com.salonapp.common.dto.PageResponse;
import com.salonapp.customer.dto.CustomerRequest;
import com.salonapp.customer.dto.CustomerResponse;
import com.salonapp.customer.dto.CustomerSummaryResponse;
import com.salonapp.customer.service.CustomerService;
import com.salonapp.customer.service.CustomerSummaryService;
import com.salonapp.sales.dto.SaleResponse;
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
 * GET  /api/customers/{id}/summary           요약 (방문 횟수, 총 결제액, 첫·최근 방문일, 최근 시술 등)
 * GET  /api/customers/{id}/visits            방문 이력 (매출 기록, 최신순, 페이징)
 *
 * 삭제 API는 아직 없다. 개인정보 파기 정책을 정한 뒤 추가한다. (ADR 0002)
 */
@Tag(name = "고객", description = "고객 카드 (이름, 연락처, 메모)")
@RestController
@RequestMapping("/api/customers")
@RequiredArgsConstructor
public class CustomerController {

    private final CustomerService customerService;
    private final CustomerSummaryService customerSummaryService;

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

    @Operation(summary = "고객 요약",
            description = "방문 횟수(매출 기록 수), 총·평균 결제액, 첫·최근 방문일, 예약·취소·노쇼 횟수, 최근 시술 메뉴와 담당. "
                    + "매출이 없으면 횟수·금액은 0, 날짜·평균·최근 시술은 null. 없는 고객은 404")
    @GetMapping("/{id}/summary")
    public CustomerSummaryResponse summary(@PathVariable Long id) {
        return customerSummaryService.summarize(id);
    }

    @Operation(summary = "고객 방문 이력",
            description = "그 고객의 매출 기록을 최신순(결제 시각, 같으면 번호가 큰 쪽 먼저)으로 20건씩. "
                    + "방문이 없으면 빈 목록. 없는 고객은 404. sort 파라미터는 무시")
    @GetMapping("/{id}/visits")
    public PageResponse<SaleResponse> visits(
            @PathVariable Long id,
            @ParameterObject @PageableDefault(size = 20) Pageable pageable
    ) {
        return customerSummaryService.visits(id, pageable);
    }

    @Operation(summary = "고객 수정")
    @PutMapping("/{id}")
    public CustomerResponse update(@PathVariable Long id, @Valid @RequestBody CustomerRequest request) {
        return customerService.update(id, request);
    }
}
