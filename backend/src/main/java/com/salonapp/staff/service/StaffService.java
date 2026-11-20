package com.salonapp.staff.service;

import com.salonapp.common.exception.NotFoundException;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.dto.StaffRequest;
import com.salonapp.staff.dto.StaffResponse;
import com.salonapp.staff.repository.StaffRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 직원 관리. 규칙은 ADR 0010, 0011.
 * 기본은 읽기 전용 트랜잭션, 쓰기 메서드만 @Transactional로 덮어쓴다. (메뉴 서비스와 같은 방식)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StaffService {

    private final StaffRepository staffRepository;

    @Transactional
    public StaffResponse create(StaffRequest request) {
        Staff staff = new Staff(request.name(), request.position());
        return StaffResponse.from(staffRepository.save(staff));
    }

    /** 직원 번호순. 기본은 근무 중인 직원만. */
    public List<StaffResponse> findAll(boolean includeInactive) {
        List<Staff> staff = includeInactive
                ? staffRepository.findAllByOrderByIdAsc()
                : staffRepository.findAllByActiveTrueOrderByIdAsc();
        return staff.stream().map(StaffResponse::from).toList();
    }

    public StaffResponse findById(Long id) {
        return StaffResponse.from(getStaff(id));
    }

    @Transactional
    public StaffResponse update(Long id, StaffRequest request) {
        Staff staff = getStaff(id);
        staff.update(request.name(), request.position());
        // save() 없이도 트랜잭션이 끝날 때 JPA가 변경을 감지해 UPDATE를 보낸다(dirty checking).
        return StaffResponse.from(staff);
    }

    /**
     * 근무 종료. 모든 직원에게 같은 규칙이다. 마지막 근무 직원도 종료할 수 있고, 실수는 재개로 복구한다. (ADR 0011)
     * 이 직원에게 이미 잡힌 앞으로의 예약은 그대로 남는다. (알려진 이슈)
     */
    @Transactional
    public void deactivate(Long id) {
        getStaff(id).deactivate();
    }

    @Transactional
    public void activate(Long id) {
        getStaff(id).activate();
    }

    private Staff getStaff(Long id) {
        return staffRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("직원을 찾을 수 없습니다. 직원 번호=" + id));
    }
}
