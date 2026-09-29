# salon-app

1인 미용사를 위한 예약·고객·매출 관리 서비스. (가칭, 브랜딩은 추후 결정)
재취업 포트폴리오 겸 실제 출시를 목표로 한다.

## 가장 중요한 원칙

- **개발자(오너)가 AI 없이도 이해하고 유지보수할 수 있어야 한다.**
  - 작게 나눠서 작업하고, 매 단계마다 "무엇을 왜 했는지" 설명한다.
  - 영리한 코드보다 읽히는 코드. 마법 같은 추상화 금지.
  - 중요한 설계 결정은 `docs/adr/`에 ADR로 남긴다.
- 기능 하나 = 설계 설명 → 구현 → 테스트 → 커밋.

## 기술 스택

Java 21, Spring Boot, Spring Data JPA, PostgreSQL, Flyway, Gradle(Groovy DSL),
JUnit 5 + Testcontainers, springdoc-openapi, Docker Compose.
클라이언트는 백엔드 이후 Flutter. 선택 근거: `docs/adr/0001-tech-stack.md`

## 코드 구조 (도메인별 패키지)

```
com.salonapp
├── customer/      고객
├── reservation/   예약
├── menu/          시술 메뉴
├── sales/         매출
├── stats/         통계
└── common/        공통(예외, 응답 포맷, 설정)
```

각 도메인 패키지 안: `controller`, `service`, `repository`, `domain`(엔티티), `dto`.
- Controller는 요청/응답 변환만. 비즈니스 로직은 Service 또는 엔티티에.
- 엔티티를 API 응답으로 직접 노출하지 않는다. 항상 DTO(record) 사용.
- DB 스키마 변경은 반드시 Flyway 마이그레이션(`db/migration/V{n}__설명.sql`)으로. `ddl-auto`는 `validate`.

## 컨벤션

- 커밋 메시지: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` + 한국어 요약.
- 테스트 이름은 한국어 허용: `@DisplayName("겹치는 시간에는 예약할 수 없다")`.
- 시간은 `Asia/Seoul` 기준, DB에는 `timestamptz`로 저장.
- 비밀값(DB 비밀번호 등)은 커밋하지 않는다. `.env` 또는 `application-local.yml` 사용.

## 자주 쓰는 명령

(Spring Boot 프로젝트 생성 후 채울 것)
