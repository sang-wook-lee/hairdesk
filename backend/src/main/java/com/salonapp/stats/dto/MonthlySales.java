package com.salonapp.stats.dto;

/** 한 달 매출. month는 "2026-10" 형식(서울 기준). 매출이 없는 달도 0으로 채워서 내려준다. */
public record MonthlySales(String month, long totalAmount, long count) {
}
