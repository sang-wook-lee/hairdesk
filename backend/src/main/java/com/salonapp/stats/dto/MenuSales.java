package com.salonapp.stats.dto;

/**
 * 메뉴별 매출 한 줄. 이름은 메뉴의 "현재" 이름이다.
 * (같은 메뉴를 이름만 바꿨을 때 매출이 둘로 쪼개지지 않도록 id로 묶는다)
 * 리포지토리의 집계 쿼리 결과를 그대로 담기도 한다.
 */
public record MenuSales(Long menuId, String menuName, long totalAmount, long count) {
}
