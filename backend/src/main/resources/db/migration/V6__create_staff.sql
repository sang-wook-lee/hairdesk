-- 직원(담당자). ADR 0010
-- 삭제하지 않고 active=false로 근무 종료 처리한다. 과거 예약·매출이 직원을 참조하게 될 것이기 때문.
-- 직원은 id(= 직원 번호)로 구분한다. 이름·직책이 같은 사람이 있을 수 있어 유니크 제약은 걸지 않는다.
CREATE TABLE staff (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(30)  NOT NULL,
    position    VARCHAR(30)  NOT NULL,                  -- 직책 (원장, 실장, 디자이너 ...). 자유 입력
    owner       BOOLEAN      NOT NULL DEFAULT FALSE,    -- 매장 주인. 담당자를 생략했을 때의 기본 담당자
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL,
    updated_at  TIMESTAMPTZ  NOT NULL
);

-- 주인은 정확히 1명. "owner가 TRUE인 행끼리만" 유니크하게 해서, TRUE는 한 행만 가능하고 FALSE는 여럿 가능하다.
-- (이 인덱스는 "최대 1명"만 보장한다. "반드시 1명"은 아래 기본 직원 INSERT와 서비스 규칙이 맡는다.)
CREATE UNIQUE INDEX uk_staff_owner ON staff (owner) WHERE owner;

-- 기본 직원 1명. 기존 예약·매출은 V7에서 이 직원의 것으로 채운다.
-- 이름과 직책은 앱에서 수정할 수 있다.
INSERT INTO staff (name, position, owner, active, created_at, updated_at)
VALUES ('원장', '원장', TRUE, TRUE, now(), now());
