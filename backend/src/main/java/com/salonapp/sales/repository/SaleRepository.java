package com.salonapp.sales.repository;

import com.salonapp.customer.dto.CustomerSaleTotals;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.dto.MethodTotal;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

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
            join fetch s.staff
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

    /**
     * 한 고객의 매출 집계: 방문 횟수(=매출 기록 수), 총 결제액, 첫·최근 방문일. (고객 요약용)
     * 방문은 예약이 아니라 매출 기록으로 센다. 예약 없이 온 손님(워크인)도 방문에 들어간다.
     * 매출이 없으면 횟수 0, 나머지는 null인 한 줄이 나온다. (CustomerSaleTotals 설명 참고)
     */
    @Query("""
            select new com.salonapp.customer.dto.CustomerSaleTotals(count(s), sum(s.amount), min(s.paidAt), max(s.paidAt))
            from Sale s
            where s.customer.id = :customerId
            """)
    CustomerSaleTotals totalsByCustomer(@Param("customerId") Long customerId);

    /**
     * 한 고객의 가장 최근 결제 1건. (최근 시술 메뉴·담당 표시용)
     * 같은 시각에 결제가 둘이면 번호가 큰 쪽이 최근이다. 기존 매출 목록과 같은 정렬 규칙.
     * 담당자 이름을 쿼리 한 번에 함께 가져오려고 @EntityGraph로 staff를 지정한다.
     */
    @EntityGraph(attributePaths = "staff")
    Optional<Sale> findFirstByCustomerIdOrderByPaidAtDescIdDesc(Long customerId);

    /**
     * 한 고객의 방문 이력(매출 기록)을 최신순으로, 페이지 단위로. (고객 상세의 "방문 이력"용)
     * 정렬은 쿼리에 고정한다(결제 시각, 같으면 번호가 큰 쪽이 먼저). Pageable에는 정렬을 담지 않는다.
     * 응답에 고객·담당자 이름이 필요하므로 둘 다 JOIN FETCH. 페이징 + JOIN FETCH는 전체 개수를 세는
     * 쿼리를 따로 지정해야 한다(countQuery).
     */
    @Query(value = """
            select s from Sale s
            join fetch s.customer
            join fetch s.staff
            where s.customer.id = :customerId
            order by s.paidAt desc, s.id desc
            """,
            countQuery = "select count(s) from Sale s where s.customer.id = :customerId")
    Page<Sale> findVisitsByCustomer(@Param("customerId") Long customerId, Pageable pageable);
}
