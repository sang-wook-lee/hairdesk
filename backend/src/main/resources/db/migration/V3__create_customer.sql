-- 고객 카드
-- 같은 번호를 가족이 함께 쓰는 경우(엄마 번호로 아이 예약)를 허용하기 위해
-- 번호 단독이 아니라 (이름, 번호) 조합을 유일하게 한다. → ADR 0002
CREATE TABLE customer (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR(30)   NOT NULL,
    phone        VARCHAR(11)   NOT NULL CHECK (phone ~ '^01[016789][0-9]{7,8}$'), -- 숫자만 저장
    gender       VARCHAR(10)   CHECK (gender IN ('FEMALE', 'MALE')),              -- 선택 입력
    memo         VARCHAR(1000),                                                   -- 두피 민감, 선호 스타일 등
    sms_consent  BOOLEAN       NOT NULL DEFAULT FALSE,                            -- 홍보 문자 수신 동의
    created_at   TIMESTAMPTZ   NOT NULL,
    updated_at   TIMESTAMPTZ   NOT NULL,
    CONSTRAINT uk_customer_name_phone UNIQUE (name, phone)
);
