package com.salonapp.stats.repository;

import com.salonapp.sales.domain.Sale;
import com.salonapp.stats.dto.MenuSales;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

/**
 * 매출 통계용 "읽기 전용" 저장소.
 *
 * JpaRepository 대신 마커 인터페이스 Repository를 상속하면 save/delete 같은 기본 메서드가 하나도 생기지 않는다.
 * 여기 적은 조회 쿼리만 존재하므로, 통계 코드가 실수로 매출을 바꿀 방법이 없다.
 *
 * 모든 기간은 [from, to) — from 이상, to 미만이다. (날짜 → 시각 변환은 SeoulDates)
 */
public interface SalesStatsRepository extends Repository<Sale, Long> {

    /** 일별 집계 한 줄. 네이티브 쿼리 결과를 받는 "인터페이스 프로젝션": 컬럼 별칭과 getter 이름이 짝이 된다. */
    interface DayRow {
        String getDay();      // "2026-10-01"
        Long getTotal();
        Long getCnt();
    }

    interface MonthRow {
        String getYm();       // "2026-10"
        Long getTotal();
        Long getCnt();
    }

    /**
     * 서울 날짜별 매출.
     *
     * nativeQuery = true: JPQL이 아니라 PostgreSQL SQL을 그대로 실행한다.
     * JPQL에는 "시간대를 바꿔서 날짜만 꺼내기"가 없어서 여기만 네이티브를 쓴다.
     *
     * paid_at은 절대 시각(timestamptz). "AT TIME ZONE 'Asia/Seoul'"로 서울 벽시계 시각으로 바꾼 뒤
     * to_char로 날짜 문자열을 만든다. 이렇게 안 하면 서울 자정 근처 매출이 UTC 날짜로 하루 밀린다.
     * (date로 캐스팅하는 대신 문자열로 받는 이유: JDBC 날짜 타입 변환 차이를 피해 가장 단순하게 받으려고)
     * group by 1 = SELECT의 첫 번째 컬럼으로 묶는다.
     */
    @Query(value = """
            select to_char(paid_at at time zone 'Asia/Seoul', 'YYYY-MM-DD') as day,
                   sum(amount) as total,
                   count(*) as cnt
            from sale
            where paid_at >= :from and paid_at < :to
            group by 1
            order by 1
            """, nativeQuery = true)
    List<DayRow> sumByDay(@Param("from") Instant from, @Param("to") Instant to);

    /** 서울 기준 월별 매출. 위와 같은 방식이고 문자열 형식만 'YYYY-MM'. */
    @Query(value = """
            select to_char(paid_at at time zone 'Asia/Seoul', 'YYYY-MM') as ym,
                   sum(amount) as total,
                   count(*) as cnt
            from sale
            where paid_at >= :from and paid_at < :to
            group by 1
            order by 1
            """, nativeQuery = true)
    List<MonthRow> sumByMonth(@Param("from") Instant from, @Param("to") Instant to);

    /**
     * 메뉴별 매출, 많이 번 순.
     * 결과를 DTO(MenuSales)에 바로 담는 JPQL 생성자 표현식. (sum/count는 Long)
     * 매출 금액이 같으면 이름순으로 정렬해서 결과 순서가 매번 같게 한다.
     */
    @Query("""
            select new com.salonapp.stats.dto.MenuSales(m.id, m.name, sum(s.amount), count(s))
            from Sale s join s.menu m
            where s.paidAt >= :from and s.paidAt < :to
            group by m.id, m.name
            order by sum(s.amount) desc, m.name
            """)
    List<MenuSales> sumByMenu(@Param("from") Instant from, @Param("to") Instant to);

    /** 기간 내 결제한 고객 수 (한 사람이 여러 번 결제해도 1명: distinct) */
    @Query("""
            select count(distinct s.customer.id) from Sale s
            where s.paidAt >= :from and s.paidAt < :to
            """)
    long countCustomers(@Param("from") Instant from, @Param("to") Instant to);

    /**
     * 기간 내 결제한 고객 중 "기간 시작 전에도 결제한 적 있는" 고객 수 = 재방문 고객.
     * exists 서브쿼리: 같은 고객의 더 이전 매출이 하나라도 있는지 본다.
     * 신규 고객 수는 (전체 - 재방문)으로 서비스에서 계산한다.
     */
    @Query("""
            select count(distinct s.customer.id) from Sale s
            where s.paidAt >= :from and s.paidAt < :to
              and exists (select 1 from Sale p where p.customer.id = s.customer.id and p.paidAt < :from)
            """)
    long countReturningCustomers(@Param("from") Instant from, @Param("to") Instant to);
}
