package com.salonapp.sales.repository;

import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.dto.MethodTotal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface SaleRepository extends JpaRepository<Sale, Long> {

    /** 이 예약에 이미 매출이 있는가 (이중 결제 방지의 친절한 사전 확인. 최종 방어는 DB UNIQUE) */
    boolean existsByReservationId(Long reservationId);

    /**
     * [from, to) 기간의 매출을 최신순으로. 화면에 고객 이름이 필요하므로 고객만 JOIN FETCH.
     * (메뉴 이름은 매출 행에 스냅샷으로 있어서 메뉴 테이블을 조인할 필요가 없다)
     * 응답에서 sale.getMenu().getId()를 쓰지만, LAZY 프록시는 id를 알고 있어 쿼리 없이 꺼낼 수 있다.
     */
    @Query("""
            select s from Sale s
            join fetch s.customer
            where s.paidAt >= :from and s.paidAt < :to
            order by s.paidAt desc, s.id desc
            """)
    List<Sale> findPaidBetween(@Param("from") Instant from, @Param("to") Instant to);

    /**
     * 결제수단별 합계. SQL의 GROUP BY 집계를 DB에서 하고, 결과를 바로 MethodTotal로 만든다.
     * ("select new ..."는 JPQL의 생성자 표현식: 조회 결과를 엔티티가 아닌 DTO에 직접 담는다)
     */
    @Query("""
            select new com.salonapp.sales.dto.MethodTotal(s.paymentMethod, sum(s.amount), count(s))
            from Sale s
            where s.paidAt >= :from and s.paidAt < :to
            group by s.paymentMethod
            order by s.paymentMethod
            """)
    List<MethodTotal> summarizeByMethod(@Param("from") Instant from, @Param("to") Instant to);
}
