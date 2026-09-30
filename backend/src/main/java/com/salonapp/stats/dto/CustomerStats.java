package com.salonapp.stats.dto;

/**
 * 기간 내 고객 통계 (정의는 ADR 0005).
 * totalCustomers = newCustomers + returningCustomers. 한 사람이 여러 번 와도 1명으로 센다.
 */
public record CustomerStats(long totalCustomers, long newCustomers, long returningCustomers) {
}
