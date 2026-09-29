# hairdesk

1인 미용사를 위한 예약·고객·매출 관리 서비스.

## 주요 기능 (MVP)

- [ ] 예약 캘린더 (이중 예약 방지)
- [ ] 고객 카드 (시술 이력, 메모)
- [x] 시술 메뉴·가격 관리 (API)
- [ ] 매출 기록
- [ ] 통계 (일/월 매출, 재방문율)

## 기술 스택

Java 21 · Spring Boot · JPA · PostgreSQL · Flyway · Testcontainers · Docker Compose

선택 근거는 [ADR 0001](docs/adr/0001-tech-stack.md) 참고.

## 설계 문서

- [ADR 목록](docs/adr/README.md)

## 실행 방법

필요: JDK 21, Docker Desktop

```bash
cd backend
./gradlew bootRun
```

PostgreSQL 컨테이너가 자동으로 뜬다.

- API 문서(Swagger UI): http://localhost:8080/swagger-ui.html
- 헬스체크: http://localhost:8080/actuator/health
