package com.salonapp.reservation.service;

import com.salonapp.common.exception.ConflictException;
import com.salonapp.common.exception.NotFoundException;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;
import com.salonapp.reservation.dto.RescheduleRequest;
import com.salonapp.reservation.dto.ReservationRequest;
import com.salonapp.reservation.dto.ReservationResponse;
import com.salonapp.reservation.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReservationService {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
    /** 시간을 차지하는 상태 (DB 제약 조건과 같아야 한다 — V4 마이그레이션, ADR 0003) */
    private static final Set<ReservationStatus> OCCUPYING = Set.of(ReservationStatus.BOOKED, ReservationStatus.COMPLETED);

    private final ReservationRepository reservationRepository;
    private final CustomerRepository customerRepository;
    private final TreatmentMenuRepository menuRepository;

    @Transactional
    public ReservationResponse create(ReservationRequest request) {
        Customer customer = customerRepository.findById(request.customerId())
                .orElseThrow(() -> new NotFoundException("고객을 찾을 수 없습니다. id=" + request.customerId()));
        TreatmentMenu menu = menuRepository.findById(request.menuId())
                .orElseThrow(() -> new NotFoundException("메뉴를 찾을 수 없습니다. id=" + request.menuId()));
        if (!menu.isActive()) {
            throw new IllegalArgumentException("판매 중지된 메뉴입니다: " + menu.getName());
        }

        Reservation reservation = new Reservation(customer, menu, request.startAt().toInstant(), request.memo());
        // 먼저 확인해서 친절한 메시지로 409를 준다. 동시 요청은 DB의 EXCLUDE 제약이 최종적으로 막는다.
        if (reservationRepository.existsByStatusInAndStartAtLessThanAndEndAtGreaterThan(
                OCCUPYING, reservation.getEndAt(), reservation.getStartAt())) {
            throw new ConflictException("해당 시간에 이미 예약이 있습니다.");
        }
        // saveAndFlush: 제약 위반을 커밋 시점이 아니라 여기서 바로 확인한다.
        return ReservationResponse.from(reservationRepository.saveAndFlush(reservation));
    }

    /** 날짜 범위(from~to, 양쪽 포함)의 예약을 시간순으로. 날짜는 서울 기준. */
    public List<ReservationResponse> findBetween(LocalDate from, LocalDate to) {
        if (to.isBefore(from)) {
            throw new IllegalArgumentException("종료 날짜가 시작 날짜보다 빠릅니다.");
        }
        Instant start = from.atStartOfDay(SEOUL).toInstant();
        Instant end = to.plusDays(1).atStartOfDay(SEOUL).toInstant();   // to 당일 24시까지 포함
        return reservationRepository.findStartingBetween(start, end).stream()
                .map(ReservationResponse::from)
                .toList();
    }

    public ReservationResponse findById(Long id) {
        return ReservationResponse.from(getReservation(id));
    }

    @Transactional
    public ReservationResponse reschedule(Long id, RescheduleRequest request) {
        Reservation reservation = getReservation(id);
        Instant newStart = request.startAt().toInstant();
        Instant newEnd = newStart.plus(Duration.between(reservation.getStartAt(), reservation.getEndAt()));
        // 엔티티를 바꾸기 "전에" 확인한다. 바꾼 뒤에 조회하면 Hibernate가 조회 직전에 UPDATE를 먼저 보내서,
        // 친절한 메시지 대신 DB 제약 위반이 먼저 터진다. 자기 자신은 IdNot으로 뺀다.
        if (reservationRepository.existsByStatusInAndStartAtLessThanAndEndAtGreaterThanAndIdNot(
                OCCUPYING, newEnd, newStart, id)) {
            throw new ConflictException("해당 시간에 이미 예약이 있습니다.");
        }
        reservation.reschedule(newStart);
        reservationRepository.flush();
        return ReservationResponse.from(reservation);
    }

    @Transactional
    public ReservationResponse cancel(Long id) {
        Reservation reservation = getReservation(id);
        reservation.cancel();
        return ReservationResponse.from(reservation);
    }

    @Transactional
    public ReservationResponse complete(Long id) {
        Reservation reservation = getReservation(id);
        reservation.complete();
        return ReservationResponse.from(reservation);
    }

    @Transactional
    public ReservationResponse markNoShow(Long id) {
        Reservation reservation = getReservation(id);
        reservation.markNoShow();
        return ReservationResponse.from(reservation);
    }

    private Reservation getReservation(Long id) {
        return reservationRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("예약을 찾을 수 없습니다. id=" + id));
    }
}
