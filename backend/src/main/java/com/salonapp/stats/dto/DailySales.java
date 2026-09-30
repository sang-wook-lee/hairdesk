package com.salonapp.stats.dto;

import java.time.LocalDate;

/** 하루 매출. 매출이 없는 날도 0으로 채워서 내려준다(그래프가 끊기지 않게). */
public record DailySales(LocalDate date, long totalAmount, long count) {
}
