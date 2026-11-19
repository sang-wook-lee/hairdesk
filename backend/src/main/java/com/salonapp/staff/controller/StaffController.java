package com.salonapp.staff.controller;

import com.salonapp.staff.dto.StaffRequest;
import com.salonapp.staff.dto.StaffResponse;
import com.salonapp.staff.service.StaffService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
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
import java.util.List;

/**
 * 직원(담당자) API. 규칙은 ADR 0010.
 *
 * POST /api/staff                       등록 → 201 (새 직원은 항상 주인이 아님)
 * GET  /api/staff?includeInactive=true  목록 (직원 번호순, 기본은 근무 중만)
 * GET  /api/staff/{id}                  단건 조회
 * PUT  /api/staff/{id}                  이름·직책 수정
 * POST /api/staff/{id}/deactivate       근무 종료 (DELETE 대신. 주인이면 409)
 * POST /api/staff/{id}/activate         근무 재개
 * POST /api/staff/{id}/make-owner       매장 주인으로 지정 (근무 중인 직원만. 이미 주인이면 그대로 성공)
 *
 * 컨트롤러는 요청/응답 변환만 하고, 규칙은 StaffService가 맡는다.
 */
@Tag(name = "직원", description = "직원(담당자) 관리. 직원 번호(id)로 구분한다")
@RestController
@RequestMapping("/api/staff")
@RequiredArgsConstructor
public class StaffController {

    private final StaffService staffService;

    @Operation(summary = "직원 등록", description = "항상 매장 주인이 아닌 직원으로 등록된다. 이름·직책이 같아도 등록할 수 있다")
    @PostMapping
    public ResponseEntity<StaffResponse> create(@Valid @RequestBody StaffRequest request) {
        StaffResponse created = staffService.create(request);
        return ResponseEntity.created(URI.create("/api/staff/" + created.id())).body(created);
    }

    @Operation(summary = "직원 목록", description = "직원 번호순. 기본은 근무 중인 직원만, includeInactive=true면 전체")
    @GetMapping
    public List<StaffResponse> findAll(@RequestParam(defaultValue = "false") boolean includeInactive) {
        return staffService.findAll(includeInactive);
    }

    @Operation(summary = "직원 단건 조회")
    @GetMapping("/{id}")
    public StaffResponse findById(@PathVariable Long id) {
        return staffService.findById(id);
    }

    @Operation(summary = "직원 수정", description = "이름과 직책만 수정한다. 주인·근무 여부는 아래 전용 요청으로 바꾼다")
    @PutMapping("/{id}")
    public StaffResponse update(@PathVariable Long id, @Valid @RequestBody StaffRequest request) {
        return staffService.update(id, request);
    }

    @Operation(summary = "근무 종료", description = "삭제 대신 사용. 과거 예약·매출 기록 보존. 매장 주인이면 409")
    @PostMapping("/{id}/deactivate")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        staffService.deactivate(id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "근무 재개")
    @PostMapping("/{id}/activate")
    public ResponseEntity<Void> activate(@PathVariable Long id) {
        staffService.activate(id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "매장 주인 지정", description = "기존 주인은 자동으로 해제된다. 근무 중인 직원만 가능(아니면 409). 이미 주인이면 아무 일 없이 204")
    @PostMapping("/{id}/make-owner")
    public ResponseEntity<Void> makeOwner(@PathVariable Long id) {
        staffService.makeOwner(id);
        return ResponseEntity.noContent().build();
    }
}
