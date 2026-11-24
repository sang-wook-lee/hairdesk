package com.salonapp.customer.dto;

import java.time.Instant;

/**
 * 한 고객의 매출 집계 결과 한 줄. (고객 요약의 방문 횟수·총 결제액·첫/최근 방문일의 재료)
 *
 * 매출이 하나도 없어도 집계 쿼리는 한 줄을 돌려준다. 이때 횟수(visitCount)는 0이지만
 * 합계와 날짜는 0이 아니라 null이다. (SQL의 SUM·MIN·MAX는 행이 없으면 null)
 * 그래서 합계와 날짜 타입은 null을 담을 수 있는 Long/Instant다.
 */
public record CustomerSaleTotals(long visitCount, Long totalAmount, Instant firstVisitAt, Instant lastVisitAt) {
}
