-- 예약 이중 방지(ADR 0001)에 필요한 확장.
-- EXCLUDE 제약에서 "같은 디자이너(=)" + "시간 겹침(&&)"을 함께 검사하려면
-- 일반 컬럼(=)을 GiST 인덱스로 다룰 수 있게 해 주는 btree_gist가 필요하다.
CREATE EXTENSION IF NOT EXISTS btree_gist;
