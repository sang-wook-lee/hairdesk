package com.salonapp.menu.domain;

/**
 * 시술 카테고리. DB에는 이름(문자열) 그대로 저장된다(@Enumerated(STRING)).
 * 값을 추가하면 V2 마이그레이션의 CHECK 제약도 새 마이그레이션으로 함께 바꿔야 한다.
 */
public enum MenuCategory {
    CUT,     // 커트
    PERM,    // 펌
    COLOR,   // 염색
    CLINIC,  // 클리닉
    ETC      // 기타
}
