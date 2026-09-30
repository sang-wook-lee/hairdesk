package com.salonapp.common.time;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

/**
 * "서울 기준 날짜"를 DB에 저장된 절대 시각(Instant)의 범위로 바꿔 주는 도구.
 *
 * 화면/API는 "10월 1일"이라는 날짜로 말하지만 DB의 timestamptz는 절대 시각이다.
 * 서울의 10월 1일은 [9/30 15:00 UTC, 10/1 15:00 UTC) 이므로, UTC 날짜로 그냥 자르면
 * 자정 근처 데이터가 하루씩 밀린다. 그래서 날짜 → 시각 변환은 반드시 이 클래스를 거친다.
 */
public final class SeoulDates {

    public static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    private SeoulDates() {
    }

    /** 해당 날짜 서울 00:00 */
    public static Instant startOfDay(LocalDate date) {
        return date.atStartOfDay(SEOUL).toInstant();
    }

    /** 해당 날짜의 "다음 날" 서울 00:00. 조회 범위의 끝(미포함)으로 쓴다: start <= t < endExclusive */
    public static Instant endOfDayExclusive(LocalDate date) {
        return date.plusDays(1).atStartOfDay(SEOUL).toInstant();
    }
}
