package com.salonapp.sales.service;

import com.salonapp.common.exception.ConflictException;
import com.salonapp.common.exception.NotFoundException;
import com.salonapp.common.time.SeoulDates;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.dto.SaleRequest;
import com.salonapp.sales.dto.SaleResponse;
import com.salonapp.sales.dto.SaleUpdateRequest;
import com.salonapp.sales.dto.SalesSummaryResponse;
import com.salonapp.sales.repository.SaleRepository;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SaleService {

    private final SaleRepository saleRepository;
    private final ReservationRepository reservationRepository;
    private final CustomerRepository customerRepository;
    private final TreatmentMenuRepository menuRepository;
    private final StaffRepository staffRepository;

    /**
     * 매출 등록. 예약 기반인지 워크인인지에 따라 갈라진다.
     * @Transactional: 아래 "예약 완료 처리"와 "매출 저장"이 한 덩어리로 성공하거나 함께 취소된다.
     * (매출 저장이 실패하면 예약이 완료 상태로 바뀐 것도 되돌려진다)
     */
    @Transactional
    public SaleResponse create(SaleRequest request) {
        Instant paidAt = request.paidAt() == null ? Instant.now() : request.paidAt().toInstant();

        Sale sale = (request.reservationId() != null)
                ? saleForReservation(request, paidAt)
                : saleForWalkIn(request, paidAt);

        // saveAndFlush: UNIQUE 위반(동시 이중 결제) 같은 DB 오류를 커밋 시점이 아니라 여기서 바로 드러낸다.
        return SaleResponse.from(saleRepository.saveAndFlush(sale));
    }

    private Sale saleForReservation(SaleRequest request, Instant paidAt) {
        // 예약 기반 요청에 고객/메뉴를 같이 보내면 어느 쪽이 맞는지 모호하다. 아예 못 받게 한다.
        if (request.customerId() != null || request.menuId() != null) {
            throw new IllegalArgumentException("예약으로 결제할 때는 customerId/menuId를 보내지 않습니다. 예약의 고객과 메뉴가 사용됩니다.");
        }
        // 담당자도 마찬가지다. 예약의 담당자가 곧 이 결제의 담당자다.
        if (request.staffId() != null) {
            throw new IllegalArgumentException("예약으로 결제할 때는 staffId를 보내지 않습니다. 예약의 담당자가 사용됩니다.");
        }
        Reservation reservation = reservationRepository.findById(request.reservationId())
                .orElseThrow(() -> new NotFoundException("예약을 찾을 수 없습니다. id=" + request.reservationId()));

        // 친절한 메시지를 위한 사전 확인. 동시 요청은 DB의 UNIQUE(reservation_id)가 최종적으로 막는다.
        if (saleRepository.existsByReservationId(reservation.getId())) {
            throw new ConflictException("이미 결제가 등록된 예약입니다. id=" + reservation.getId());
        }

        // 결제 = 시술 완료. 예약됨이면 여기서 완료 처리하고, 이미 완료면 그대로 둔다.
        // 취소/노쇼 예약에는 매출이 생기면 안 된다.
        ReservationStatus status = reservation.getStatus();
        if (status == ReservationStatus.BOOKED) {
            reservation.complete();
        } else if (status != ReservationStatus.COMPLETED) {
            throw new ConflictException("취소되었거나 노쇼 처리된 예약에는 결제를 등록할 수 없습니다. 현재 상태: " + status);
        }

        return Sale.forReservation(reservation, request.amount(), request.paymentMethod(), paidAt, request.memo());
    }

    private Sale saleForWalkIn(SaleRequest request, Instant paidAt) {
        if (request.customerId() == null || request.menuId() == null) {
            throw new IllegalArgumentException("reservationId가 없으면 customerId와 menuId가 필요합니다.");
        }
        Customer customer = customerRepository.findById(request.customerId())
                .orElseThrow(() -> new NotFoundException("고객을 찾을 수 없습니다. id=" + request.customerId()));
        TreatmentMenu menu = menuRepository.findById(request.menuId())
                .orElseThrow(() -> new NotFoundException("메뉴를 찾을 수 없습니다. id=" + request.menuId()));
        // 판매 중지 메뉴도 매출은 받을 수 있게 둔다: 이미 시술이 끝난 뒤 기록하는 것이라 막을 이유가 없다.
        Staff staff = findStaff(request.staffId());
        return Sale.walkIn(customer, menu, staff, request.amount(), request.paymentMethod(), paidAt, request.memo());
    }

    /**
     * 워크인 매출의 담당자. 직접 지정해야 하고(없으면 400), 없는 직원이면 404.
     * 근무를 마친 직원도 허용한다: 매출은 이미 끝난 시술을 기록하는 것이다. (판매 중지 메뉴를 허용하는 것과 같은 이유)
     */
    private Staff findStaff(Long staffId) {
        if (staffId == null) {
            throw new IllegalArgumentException("워크인 매출에는 staffId(담당자)가 필요합니다.");
        }
        return staffRepository.findById(staffId)
                .orElseThrow(() -> new NotFoundException("직원을 찾을 수 없습니다. 직원 번호=" + staffId));
    }

    /** 기간(from~to, 양쪽 포함, 서울 기준 날짜)의 매출을 최신순으로 */
    public List<SaleResponse> findBetween(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        return saleRepository.findPaidBetween(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to)).stream()
                .map(SaleResponse::from)
                .toList();
    }

    public SalesSummaryResponse summarize(LocalDate from, LocalDate to) {
        requireValidRange(from, to);
        return SalesSummaryResponse.from(
                saleRepository.summarizeByMethod(SeoulDates.startOfDay(from), SeoulDates.endOfDayExclusive(to)));
    }

    public SaleResponse findById(Long id) {
        return SaleResponse.from(getSale(id));
    }

    @Transactional
    public SaleResponse update(Long id, SaleUpdateRequest request) {
        Sale sale = getSale(id);
        // 엔티티의 값만 바꾸면 트랜잭션이 끝날 때 Hibernate가 변경을 감지해 UPDATE를 보낸다. (더티 체킹)
        // 그래서 save()를 다시 부를 필요가 없다.
        sale.correct(request.amount(), request.paymentMethod(), request.paidAt().toInstant(), request.memo());
        return SaleResponse.from(sale);
    }

    private void requireValidRange(LocalDate from, LocalDate to) {
        if (to.isBefore(from)) {
            throw new IllegalArgumentException("종료 날짜가 시작 날짜보다 빠릅니다.");
        }
    }

    private Sale getSale(Long id) {
        return saleRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("매출을 찾을 수 없습니다. id=" + id));
    }
}
