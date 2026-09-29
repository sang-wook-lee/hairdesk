-- 시술 메뉴 (커트, 펌, 염색 ...)
-- 삭제하지 않고 active=false로 판매 중지한다. 과거 매출이 이 메뉴를 참조하기 때문.
CREATE TABLE treatment_menu (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             VARCHAR(50)  NOT NULL,
    category         VARCHAR(20)  NOT NULL
        CHECK (category IN ('CUT', 'PERM', 'COLOR', 'CLINIC', 'ETC')),
    price            INTEGER      NOT NULL CHECK (price >= 0),           -- 원 단위
    duration_minutes INTEGER      NOT NULL CHECK (duration_minutes > 0), -- 예약 종료 시각 계산용
    active           BOOLEAN      NOT NULL DEFAULT TRUE,
    display_order    INTEGER      NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ  NOT NULL,
    updated_at       TIMESTAMPTZ  NOT NULL
);
