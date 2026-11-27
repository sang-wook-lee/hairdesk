package com.salonapp.reservation.repository;

import com.salonapp.customer.dto.ReservationStatusCount;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.domain.ReservationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

public interface ReservationRepository extends JpaRepository<Reservation, Long> {

    /**
     * [from, to) 사이에 시작하는 예약을 시간순으로. 화면에 이름을 보여줘야 하므로
     * 고객/메뉴/담당자를 JOIN FETCH로 한 번에 가져온다. (예약마다 쿼리가 또 나가는 N+1 방지)
     */
    @Query("""
            select r from Reservation r
            join fetch r.customer
            join fetch r.menu
            join fetch r.staff
            where r.startAt >= :from and r.startAt < :to
            order by r.startAt
            """)
    List<Reservation> findStartingBetween(@Param("from") Instant from, @Param("to") Instant to);

    /**
     * 겹침 판정: 같은 직원의 기존.start < 새.end AND 기존.end > 새.start
     * 부등호에 등호가 없어서, 딱 맞닿는 예약(15:00 끝 / 15:00 시작)은 겹침이 아니다.
     * 직원이 다르면 같은 시간도 겹침이 아니다. (ADR 0010. DB 제약 ex_reservation_no_overlap_per_staff와 같은 기준)
     */
    boolean existsByStaffIdAndStatusInAndStartAtLessThanAndEndAtGreaterThan(
            Long staffId, Collection<ReservationStatus> statuses, Instant end, Instant start);

    /** 위와 같지만 자기 자신은 제외 (시간 변경용) */
    boolean existsByStaffIdAndStatusInAndStartAtLessThanAndEndAtGreaterThanAndIdNot(
            Long staffId, Collection<ReservationStatus> statuses, Instant end, Instant start, Long id);

    /**
     * 한 고객의 예약됨(BOOKED) 상태 예약 전부를 시작 시각 순으로. (고객 상세의 "다음 예약"용)
     * 시작 시각이 이미 지났는데 완료·취소·노쇼 처리가 안 된 예약도 포함한다. 놓치지 않고 보여주려는 것.
     * 같은 시각이면 번호가 작은 쪽이 먼저. 화면에 필요한 메뉴·담당자를 JOIN FETCH로 한 번에 가져온다.
     */
    @Query("""
            select r from Reservation r
            join fetch r.customer
            join fetch r.menu
            join fetch r.staff
            where r.customer.id = :customerId and r.status = com.salonapp.reservation.domain.ReservationStatus.BOOKED
            order by r.startAt, r.id
            """)
    List<Reservation> findBookedByCustomer(@Param("customerId") Long customerId);

    /** 한 고객의 예약 상태별 건수. 예약이 없는 상태는 줄 자체가 나오지 않는다. (고객 요약용) */
    @Query("""
            select new com.salonapp.customer.dto.ReservationStatusCount(r.status, count(r))
            from Reservation r
            where r.customer.id = :customerId
            group by r.status
            order by r.status
            """)
    List<ReservationStatusCount> countByStatusForCustomer(@Param("customerId") Long customerId);
}
