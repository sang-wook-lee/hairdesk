package com.salonapp.reservation.repository;

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
     * 고객/메뉴를 JOIN FETCH로 한 번에 가져온다. (예약마다 쿼리가 또 나가는 N+1 방지)
     */
    @Query("""
            select r from Reservation r
            join fetch r.customer
            join fetch r.menu
            where r.startAt >= :from and r.startAt < :to
            order by r.startAt
            """)
    List<Reservation> findStartingBetween(@Param("from") Instant from, @Param("to") Instant to);

    /**
     * 겹침 판정: 기존.start < 새.end AND 기존.end > 새.start
     * 부등호에 등호가 없어서, 딱 맞닿는 예약(15:00 끝 / 15:00 시작)은 겹침이 아니다.
     */
    boolean existsByStatusInAndStartAtLessThanAndEndAtGreaterThan(
            Collection<ReservationStatus> statuses, Instant end, Instant start);

    /** 위와 같지만 자기 자신은 제외 (시간 변경용) */
    boolean existsByStatusInAndStartAtLessThanAndEndAtGreaterThanAndIdNot(
            Collection<ReservationStatus> statuses, Instant end, Instant start, Long id);
}
