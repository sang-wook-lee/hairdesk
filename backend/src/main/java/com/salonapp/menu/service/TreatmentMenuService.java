package com.salonapp.menu.service;

import com.salonapp.common.exception.NotFoundException;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.dto.MenuRequest;
import com.salonapp.menu.dto.MenuResponse;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 기본은 읽기 전용 트랜잭션, 쓰기 메서드만 @Transactional로 덮어쓴다.
 * 읽기 전용이면 Hibernate가 변경 감지(스냅샷 비교)를 생략해서 조금 더 가볍다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TreatmentMenuService {

    private final TreatmentMenuRepository menuRepository;

    @Transactional
    public MenuResponse create(MenuRequest request) {
        TreatmentMenu menu = new TreatmentMenu(
                request.name(),
                request.category(),
                request.price(),
                request.durationMinutes(),
                request.displayOrder()
        );
        return MenuResponse.from(menuRepository.save(menu));
    }

    public List<MenuResponse> findAll(boolean includeInactive) {
        List<TreatmentMenu> menus = includeInactive
                ? menuRepository.findAllByOrderByDisplayOrderAscIdAsc()
                : menuRepository.findAllByActiveTrueOrderByDisplayOrderAscIdAsc();
        return menus.stream().map(MenuResponse::from).toList();
    }

    public MenuResponse findById(Long id) {
        return MenuResponse.from(getMenu(id));
    }

    @Transactional
    public MenuResponse update(Long id, MenuRequest request) {
        TreatmentMenu menu = getMenu(id);
        menu.update(
                request.name(),
                request.category(),
                request.price(),
                request.durationMinutes(),
                request.displayOrder()
        );
        // save()를 호출하지 않아도 된다. 트랜잭션이 끝날 때 JPA가 변경을 감지해 UPDATE를 보낸다(dirty checking).
        return MenuResponse.from(menu);
    }

    @Transactional
    public void deactivate(Long id) {
        getMenu(id).deactivate();
    }

    @Transactional
    public void activate(Long id) {
        getMenu(id).activate();
    }

    private TreatmentMenu getMenu(Long id) {
        return menuRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("메뉴를 찾을 수 없습니다. id=" + id));
    }
}
