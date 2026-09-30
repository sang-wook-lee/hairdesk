package com.salonapp.stats.repository;

import com.salonapp.reservation.domain.Reservation;
import com.salonapp.stats.dto.StatusCount;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

/** 예약 통계용 읽기 전용 저장소. (마커 Repository를 쓰는 이유는 SalesStatsRepository 참고) */
public interface ReservationStatsRepository extends Repository<Reservation, Long> {

    /** [from, to)에 시작하는 예약의 상태별 건수. 건수가 0인 상태는 행이 나오지 않는다. */
    @Query("""
            select new com.salonapp.stats.dto.StatusCount(r.status, count(r))
            from Reservation r
            where r.startAt >= :from and r.startAt < :to
            group by r.status
            """)
    List<StatusCount> countByStatus(@Param("from") Instant from, @Param("to") Instant to);
}
