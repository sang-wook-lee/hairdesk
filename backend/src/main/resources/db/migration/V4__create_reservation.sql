-- 예약. 1인 미용실이므로 "동시에 한 명만" 받는다 → ADR 0003
-- end_at은 시작 시각 + 메뉴 소요시간으로 서비스가 계산해 저장한다.
-- (나중에 메뉴 소요시간을 바꿔도 이미 잡힌 예약 시간은 그대로여야 하기 때문)
CREATE TABLE reservation (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  BIGINT       NOT NULL REFERENCES customer (id),
    menu_id      BIGINT       NOT NULL REFERENCES treatment_menu (id),
    start_at     TIMESTAMPTZ  NOT NULL,
    end_at       TIMESTAMPTZ  NOT NULL,
    status       VARCHAR(20)  NOT NULL DEFAULT 'BOOKED'
        CHECK (status IN ('BOOKED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    memo         VARCHAR(500),
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ck_reservation_time CHECK (end_at > start_at),
    -- 시간 구간이 겹치는(&&) 두 예약을 DB가 거부한다. 구간은 [start, end) 이므로
    -- 14:00~15:00 예약 뒤에 15:00 시작 예약은 허용된다.
    -- 취소/노쇼는 자리를 차지하지 않으므로 조건(WHERE)에서 제외한다.
    CONSTRAINT ex_reservation_no_overlap
        EXCLUDE USING gist (tstzrange(start_at, end_at) WITH &&)
        WHERE (status IN ('BOOKED', 'COMPLETED'))
);

CREATE INDEX idx_reservation_start_at ON reservation (start_at);
CREATE INDEX idx_reservation_customer ON reservation (customer_id);
