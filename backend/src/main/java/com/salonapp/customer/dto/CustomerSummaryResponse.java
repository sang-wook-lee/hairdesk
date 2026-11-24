package com.salonapp.customer.dto;

import java.time.OffsetDateTime;

/**
 * 고객 요약. 저장해 둔 값이 아니라 조회할 때 매출·예약 기록에서 계산한 값이다.
 * (저장해 두면 매출을 정정할 때마다 어긋나기 때문)
 *
 * 방문은 예약이 아니라 매출 기록으로 센다. 예약 없이 온 손님(워크인)도 방문이다.
 * 매출이 없는 고객은 횟수와 금액이 0이고, 날짜·평균·최근 시술 정보는 null이다.
 */
public record CustomerSummaryResponse(
        long visitCount,                 // 방문 횟수 (= 매출 기록 수)
        OffsetDateTime firstVisitAt,     // 첫 방문일 (가장 이른 결제 시각, +09:00). 없으면 null
        OffsetDateTime lastVisitAt,      // 최근 방문일 (가장 늦은 결제 시각). 없으면 null
        long totalAmount,                // 총 결제액 (정가가 아니라 실제 받은 금액의 합)
        Long averageAmount,              // 평균 결제액 (원 단위 반올림). 방문이 없으면 null
        long reservationCount,           // 지금까지 만든 예약 수 (모든 상태)
        long cancelledCount,             // 취소 횟수
        long noShowCount,                // 노쇼 횟수
        String lastMenuName,             // 최근 시술 메뉴 (결제 당시 이름). 없으면 null
        Long lastStaffId,                // 최근 시술 담당. 없으면 null
        String lastStaffName,
        String lastStaffPosition
) {
}
