# hairdesk

1인 미용사를 위한 예약·고객·매출 관리 서비스. (서비스 브랜드명은 추후 결정)
재취업 포트폴리오 겸 실제 출시를 목표로 한다.

## 가장 중요한 원칙

- **개발자(오너)가 AI 없이도 이해하고 유지보수할 수 있어야 한다.**
  - 작게 나눠서 작업하고, 매 단계마다 "무엇을 왜 했는지" 설명한다.
  - 영리한 코드보다 읽히는 코드. 마법 같은 추상화 금지.
  - 중요한 설계 결정은 `docs/adr/`에 ADR로 남긴다.
- 기능 하나 = 설계 설명 → 구현 → 테스트 → 커밋.
- **한 단계(기능·층)를 끝내 커밋할 때 `docs/PROGRESS.md`도 같이 갱신한다.** (진행 현황 표, 타임라인, 로드맵 체크박스, 테스트 개수, 알려진 이슈. 규칙은 그 문서 맨 아래 "문서 관리")

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

## 저장소 구조

- `backend/` Spring Boot API (Spring Boot 4.1, Gradle 9)
- `docs/adr/` 설계 결정 기록
- `docs/PROGRESS.md` **진행 현황·타임라인·로드맵** (기준 문서)
- `docs/blog/` 블로그 글 초안과 캡처 이미지
- `app/` Flutter 클라이언트 (현재 Chrome 웹 우선. Android/Windows 도구는 미설치)
  - `lib/core/` 공통(API 클라이언트), `lib/features/` 화면 단위 기능

## 자주 쓰는 명령 (`backend/`에서 실행, Docker Desktop 실행 필요)

```bash
./gradlew bootRun   # 서버 실행. compose.yaml의 PostgreSQL을 자동으로 띄움
./gradlew test      # 테스트. Testcontainers가 테스트용 PostgreSQL을 따로 띄움
./gradlew build     # 컴파일 + 테스트 + jar 생성
```

프론트 (`app/`에서 실행. Flutter는 `C:\dev\flutter`에 설치, PATH 미등록이라 경로 지정 필요):

```bash
C:\dev\flutter\bin\flutter run -d chrome   # 개발 실행(핫 리로드). 백엔드를 먼저 켜 둘 것
C:\dev\flutter\bin\flutter test            # 테스트
C:\dev\flutter\bin\flutter analyze         # 정적 분석
```

- 한글 JSON은 `response.body`가 아니라 `utf8.decode(response.bodyBytes)`로 읽는다 (`ApiClient` 참고).
- 브라우저에서 API를 부르려면 백엔드 CORS 허용이 필요하다 (`CorsConfig`). 허용 출처는 localhost와 **사설 IP(집 안 네트워크)** 뿐이다. 도메인 이름은 막는다. (ADR 0009)
- 앱의 서버 주소는 `--dart-define=API_BASE_URL=주소`로 바꾼다. 안 주면 `http://localhost:8080`.
- **폰으로 보기(같은 와이파이)**: 백엔드를 켠 뒤 저장소 맨 위에서 `powershell -ExecutionPolicy Bypass -File scripts\phone-preview.ps1`. 개발 DB 포트(5432)가 같은 네트워크에 열리므로 믿을 수 있는 네트워크에서만.

개발용 샘플 데이터 (`DevDataSeeder`):
- `./gradlew bootRun`은 `local` 프로필로 켜지고, **DB가 비어 있으면** 서버가 켜질 때 샘플 데이터(메뉴 8, 고객 12, 오늘 기준 과거 60일~앞으로 7일의 예약·매출)를 자동으로 넣는다.
- 이미 데이터가 있으면 건너뛴다. 처음부터 다시 채우려면 `backend/`에서 `docker compose down -v`(개발 DB 데이터 전부 삭제) 후 다시 `bootRun`.
- 테스트와 운영에서는 돌지 않는다. 샘플 내용을 바꾸려면 `backend/src/main/java/com/salonapp/common/dev/DevDataSeeder.java`.

- 헬스체크: http://localhost:8080/actuator/health
- API 문서(Swagger UI): http://localhost:8080/swagger-ui.html
- 로컬 DB 접속: `localhost:5432`, db/user/password 모두 `salon`
