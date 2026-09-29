package com.salonapp.menu.controller;

import com.salonapp.menu.dto.MenuRequest;
import com.salonapp.menu.dto.MenuResponse;
import com.salonapp.menu.service.TreatmentMenuService;
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
 * 시술 메뉴 API.
 *
 * POST /api/menus                  등록 → 201 Created
 * GET  /api/menus                  판매 중인 메뉴 목록 (?includeInactive=true 면 전체)
 * GET  /api/menus/{id}             단건 조회
 * PUT  /api/menus/{id}             수정
 * POST /api/menus/{id}/deactivate  판매 중지 (DELETE 대신. 과거 매출 보존)
 * POST /api/menus/{id}/activate    판매 재개
 */
@RestController
@RequestMapping("/api/menus")
@RequiredArgsConstructor
public class TreatmentMenuController {

    private final TreatmentMenuService menuService;

    @PostMapping
    public ResponseEntity<MenuResponse> create(@Valid @RequestBody MenuRequest request) {
        MenuResponse created = menuService.create(request);
        return ResponseEntity.created(URI.create("/api/menus/" + created.id())).body(created);
    }

    @GetMapping
    public List<MenuResponse> findAll(@RequestParam(defaultValue = "false") boolean includeInactive) {
        return menuService.findAll(includeInactive);
    }

    @GetMapping("/{id}")
    public MenuResponse findById(@PathVariable Long id) {
        return menuService.findById(id);
    }

    @PutMapping("/{id}")
    public MenuResponse update(@PathVariable Long id, @Valid @RequestBody MenuRequest request) {
        return menuService.update(id, request);
    }

    @PostMapping("/{id}/deactivate")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        menuService.deactivate(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/activate")
    public ResponseEntity<Void> activate(@PathVariable Long id) {
        menuService.activate(id);
        return ResponseEntity.noContent().build();
    }
}
