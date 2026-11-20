-- owner(매장 주인) 표시를 없앤다. ADR 0011
--
-- 주인은 매장에서 일하는 총책임자인데, 그건 직책("원장")으로 이미 표현된다.
-- 담당자는 항상 요청에서 직접 지정하므로 "기본 담당자"로 쓰이던 owner도 필요 없다.
-- V6이 만든 기본 직원 "원장"은 직책이 원장인 평범한 직원으로 남는다.
-- (V6·V7은 이미 적용된 이력이므로 고치지 않는다. V7은 owner를 읽는 UPDATE를 하지만 V8보다 먼저 실행된다.)
DROP INDEX uk_staff_owner;
ALTER TABLE staff DROP COLUMN owner;
