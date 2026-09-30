-- 매출 (결제 기록). 장부이므로 삭제 API는 없고 수정만 가능하다 → ADR 0004
--
-- menu_name, price는 "결제 시점의 스냅샷"이다. 메뉴 이름/가격이 나중에 바뀌어도
-- 과거 매출이 변하지 않게 하려고 menu를 참조하는 것과 별개로 값을 복사해 둔다.
-- price(정가)와 amount(실제 받은 금액)가 다르면 그 차이가 할인액이다.
CREATE TABLE sale (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- 예약 없이 온 손님(워크인)은 NULL. 값이 있으면 예약 하나당 매출 하나만 (UNIQUE) → 이중 결제 방지.
    -- PostgreSQL의 UNIQUE는 NULL끼리는 충돌로 보지 않으므로 워크인 매출은 여러 건 가능하다.
    reservation_id BIGINT       UNIQUE REFERENCES reservation (id),
    customer_id    BIGINT       NOT NULL REFERENCES customer (id),
    menu_id        BIGINT       NOT NULL REFERENCES treatment_menu (id),
    menu_name      VARCHAR(50)  NOT NULL,
    price          INTEGER      NOT NULL CHECK (price >= 0),    -- 정가(원)
    amount         INTEGER      NOT NULL CHECK (amount >= 0),   -- 실제 받은 금액(원)
    payment_method VARCHAR(20)  NOT NULL
        CHECK (payment_method IN ('CASH', 'CARD', 'TRANSFER', 'ETC')),
    paid_at        TIMESTAMPTZ  NOT NULL,                       -- 매출 날짜의 기준
    memo           VARCHAR(500),
    created_at     TIMESTAMPTZ  NOT NULL,
    updated_at     TIMESTAMPTZ  NOT NULL
);

-- 기간별 매출 조회/합계가 paid_at 범위 검색이므로 인덱스
CREATE INDEX idx_sale_paid_at ON sale (paid_at);
CREATE INDEX idx_sale_customer ON sale (customer_id);
