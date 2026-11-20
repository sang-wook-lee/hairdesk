-- 예약·매출에 담당자(staff) 연결. ADR 0010
--
-- 이미 데이터가 들어 있는 테이블에 NOT NULL 컬럼을 바로 추가할 수 없으므로 세 단계로 한다.
--   1) NULL을 허용하는 컬럼으로 추가  2) 기존 행을 주인(원장)으로 채움  3) NOT NULL로 변경

-- 1) 컬럼 추가 (외래 키: 존재하는 직원만 가리킬 수 있다)
ALTER TABLE reservation ADD COLUMN staff_id BIGINT REFERENCES staff (id);
ALTER TABLE sale        ADD COLUMN staff_id BIGINT REFERENCES staff (id);

-- 2) 기존 예약·매출은 모두 V6가 만든 주인(원장)의 것으로 채운다.
UPDATE reservation SET staff_id = (SELECT id FROM staff WHERE owner);
UPDATE sale        SET staff_id = (SELECT id FROM staff WHERE owner);

-- 3) 이제부터 담당자 없는 예약·매출은 있을 수 없다.
ALTER TABLE reservation ALTER COLUMN staff_id SET NOT NULL;
ALTER TABLE sale        ALTER COLUMN staff_id SET NOT NULL;

-- 겹침 규칙 교체: "전체 예약 중 겹침 금지" → "같은 직원의 예약끼리만 겹침 금지"
-- 취소/노쇼는 자리를 차지하지 않으므로 이전과 같이 조건(WHERE)에서 제외한다.
-- (staff_id를 = 로 비교하는 GiST 인덱스는 V1의 btree_gist 확장이 있어서 가능하다.)
-- 같은 고객이 같은 시간에 서로 다른 직원에게 예약하는 것은 막지 않는다. (가족 손님, ADR 0010)
ALTER TABLE reservation DROP CONSTRAINT ex_reservation_no_overlap;
ALTER TABLE reservation
    ADD CONSTRAINT ex_reservation_no_overlap_per_staff
        EXCLUDE USING gist (staff_id WITH =, tstzrange(start_at, end_at) WITH &&)
        WHERE (status IN ('BOOKED', 'COMPLETED'));

-- 직원별 조회용 (겹침 제약의 인덱스가 있지만 시간 범위 검색에 맞춰진 것이라 따로 둔다)
CREATE INDEX idx_reservation_staff ON reservation (staff_id);
CREATE INDEX idx_sale_staff ON sale (staff_id);
