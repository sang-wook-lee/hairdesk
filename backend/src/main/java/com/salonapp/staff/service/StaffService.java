package com.salonapp.staff.service;

import com.salonapp.common.exception.ConflictException;
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
 * 직원 관리. 규칙은 ADR 0010.
 * 기본은 읽기 전용 트랜잭션, 쓰기 메서드만 @Transactional로 덮어쓴다. (메뉴 서비스와 같은 방식)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StaffService {

    private final StaffRepository staffRepository;

    /** 새 직원은 항상 주인이 아니다. 주인은 makeOwner로만 바뀐다. */
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

    /** 근무 종료. 주인은 종료할 수 없다. 먼저 다른 직원에게 주인을 넘겨야 한다. */
    @Transactional
    public void deactivate(Long id) {
        Staff staff = getStaff(id);
        if (staff.isOwner()) {
            throw new ConflictException("매장 주인은 근무를 종료할 수 없습니다. 먼저 다른 직원을 주인으로 바꿔 주세요.");
        }
        staff.deactivate();
    }

    @Transactional
    public void activate(Long id) {
        getStaff(id).activate();
    }

    /**
     * 매장 주인을 이 직원으로 바꾼다. 근무 중인 직원만 주인이 될 수 있다.
     * 이미 주인이면 아무것도 하지 않고 성공한다(같은 요청을 다시 보내도 결과가 같다).
     *
     * 순서가 중요하다: 기존 주인의 표시를 끄고 DB에 먼저 반영(flush)한 뒤에 새 주인의 표시를 켠다.
     * "주인은 최대 1명" 제약 때문에, 켜는 UPDATE가 먼저 나가면 잠깐 주인이 둘이 되어 거부된다.
     * 전체가 한 트랜잭션이라 중간에 실패하면 모두 되돌아가서, 주인이 없는 상태가 남지 않는다.
     */
    @Transactional
    public void makeOwner(Long id) {
        Staff next = getStaff(id);
        if (next.isOwner()) {
            return;
        }
        if (!next.isActive()) {
            throw new ConflictException("근무 중인 직원만 매장 주인이 될 수 있습니다.");
        }
        staffRepository.findByOwnerTrue().ifPresent(current -> {
            current.unmarkAsOwner();
            staffRepository.flush();
        });
        next.markAsOwner();
    }

    private Staff getStaff(Long id) {
        return staffRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("직원을 찾을 수 없습니다. 직원 번호=" + id));
    }
}
