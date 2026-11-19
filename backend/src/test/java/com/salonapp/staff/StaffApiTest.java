package com.salonapp.staff;

import com.salonapp.TestcontainersConfiguration;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 직원 API 통합 테스트. HTTP 요청 → 컨트롤러 → 서비스 → 실제 PostgreSQL(Testcontainers)까지 거친다.
 * 테스트마다 롤백되므로, 마이그레이션이 만든 기본 직원 "원장"(주인) 1명에서 항상 시작한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class StaffApiTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    EntityManager entityManager;

    @Test
    @DisplayName("직원을 등록하면 201과 함께 주인이 아닌 근무 중 직원을 돌려준다")
    void create() throws Exception {
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "디자이너")))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.name").value("김하나"))
                .andExpect(jsonPath("$.position").value("디자이너"))
                .andExpect(jsonPath("$.owner").value(false))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("등록 요청에 owner=true를 실어 보내도 무시되고 주인이 아닌 직원으로 등록된다")
    void createIgnoresOwnerField() throws Exception {
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"김하나","position":"원장","owner":true,"active":false}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.owner").value(false))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("이름이나 직책이 비었거나 30자를 넘으면 400을 돌려준다")
    void createInvalid() throws Exception {
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("", "디자이너")))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", " ")))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("가".repeat(31), "디자이너")))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("이름과 직책이 같은 직원을 또 등록하면 직원 번호가 다른 별개의 직원이 된다")
    void sameNameAndPosition() throws Exception {
        long first = createStaff("이지수", "실장");
        long second = createStaff("이지수", "실장");

        org.assertj.core.api.Assertions.assertThat(first).isNotEqualTo(second);
        mockMvc.perform(get("/api/staff"))
                .andExpect(jsonPath("$", hasSize(3))); // 원장 + 둘
    }

    @Test
    @DisplayName("목록은 직원 번호순이고, 근무를 마친 직원은 기본적으로 빠진다")
    void listExcludesInactive() throws Exception {
        long left = createStaff("박민수", "디자이너");
        createStaff("김하나", "디자이너");
        mockMvc.perform(post("/api/staff/{id}/deactivate", left))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/staff"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].name").value("원장"))
                .andExpect(jsonPath("$[1].name").value("김하나"));

        mockMvc.perform(get("/api/staff").param("includeInactive", "true"))
                .andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[1].name").value("박민수"))   // 번호순이라 먼저 등록한 사람이 앞
                .andExpect(jsonPath("$[2].name").value("김하나"));
    }

    @Test
    @DisplayName("이름과 직책을 수정하면 바뀐 값이 조회되고, 주인·근무 여부는 그대로다")
    void update() throws Exception {
        long id = createStaff("김하나", "디자이너");

        mockMvc.perform(put("/api/staff/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "실장")))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/staff/{id}", id))
                .andExpect(jsonPath("$.position").value("실장"))
                .andExpect(jsonPath("$.owner").value(false))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("없는 직원 번호로 조회·수정·근무 종료·주인 지정을 하면 404를 돌려준다")
    void notFound() throws Exception {
        mockMvc.perform(get("/api/staff/{id}", 999_999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("직원을 찾을 수 없습니다. 직원 번호=999999"));
        mockMvc.perform(put("/api/staff/{id}", 999_999)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "실장")))
                .andExpect(status().isNotFound());
        mockMvc.perform(post("/api/staff/{id}/deactivate", 999_999)).andExpect(status().isNotFound());
        mockMvc.perform(post("/api/staff/{id}/make-owner", 999_999)).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("근무를 종료했다가 다시 재개할 수 있다")
    void deactivateAndActivate() throws Exception {
        long id = createStaff("김하나", "디자이너");

        mockMvc.perform(post("/api/staff/{id}/deactivate", id)).andExpect(status().isNoContent());
        mockMvc.perform(get("/api/staff/{id}", id)).andExpect(jsonPath("$.active").value(false));

        mockMvc.perform(post("/api/staff/{id}/activate", id)).andExpect(status().isNoContent());
        mockMvc.perform(get("/api/staff/{id}", id)).andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("매장 주인은 근무를 종료할 수 없다(409), 주인을 넘긴 뒤에는 종료할 수 있다")
    void ownerCannotBeDeactivated() throws Exception {
        long ownerId = ownerId();

        mockMvc.perform(post("/api/staff/{id}/deactivate", ownerId))
                .andExpect(status().isConflict());
        mockMvc.perform(get("/api/staff/{id}", ownerId))
                .andExpect(jsonPath("$.active").value(true));

        long next = createStaff("이지수", "원장");
        mockMvc.perform(post("/api/staff/{id}/make-owner", next)).andExpect(status().isNoContent());
        mockMvc.perform(post("/api/staff/{id}/deactivate", ownerId)).andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("주인을 다른 직원으로 바꾸면 기존 주인은 해제되고 주인은 항상 한 명이다")
    void changeOwner() throws Exception {
        long oldOwner = ownerId();
        long next = createStaff("이지수", "원장"); // 직책이 같은 "원장"이어도 주인은 별개
        resetPersistenceContext();

        mockMvc.perform(post("/api/staff/{id}/make-owner", next)).andExpect(status().isNoContent());

        mockMvc.perform(get("/api/staff/{id}", next)).andExpect(jsonPath("$.owner").value(true));
        mockMvc.perform(get("/api/staff/{id}", oldOwner)).andExpect(jsonPath("$.owner").value(false));
        mockMvc.perform(get("/api/staff").param("includeInactive", "true"))
                .andExpect(jsonPath("$[?(@.owner == true)]", hasSize(1)));
    }

    @Test
    @DisplayName("이미 주인인 직원에게 주인 지정을 다시 해도 에러 없이 성공한다")
    void makeOwnerIsIdempotent() throws Exception {
        long ownerId = ownerId();

        mockMvc.perform(post("/api/staff/{id}/make-owner", ownerId)).andExpect(status().isNoContent());
        mockMvc.perform(post("/api/staff/{id}/make-owner", ownerId)).andExpect(status().isNoContent());

        mockMvc.perform(get("/api/staff/{id}", ownerId)).andExpect(jsonPath("$.owner").value(true));
    }

    @Test
    @DisplayName("근무 중이 아닌 직원은 주인이 될 수 없고(409), 기존 주인은 그대로 남는다")
    void inactiveCannotBecomeOwner() throws Exception {
        long oldOwner = ownerId();
        long left = createStaff("박민수", "디자이너");
        mockMvc.perform(post("/api/staff/{id}/deactivate", left)).andExpect(status().isNoContent());

        mockMvc.perform(post("/api/staff/{id}/make-owner", left))
                .andExpect(status().isConflict());

        mockMvc.perform(get("/api/staff/{id}", oldOwner)).andExpect(jsonPath("$.owner").value(true));
        mockMvc.perform(get("/api/staff/{id}", left)).andExpect(jsonPath("$.owner").value(false));
    }

    /**
     * 테스트는 통째로 한 트랜잭션이라 앞서 조회한 직원이 메모리(영속성 컨텍스트)에 남아 있다.
     * 실제 서비스는 요청마다 DB에서 새로 불러오므로 같은 조건이 되도록 비운다.
     * 이걸 안 하면 UPDATE 순서가 우연히 맞아서, 서비스의 flush()를 빼도 테스트가 통과해 버린다.
     */
    private void resetPersistenceContext() {
        entityManager.flush();
        entityManager.clear();
    }

    /** 목록에서 주인(owner=true)의 직원 번호를 찾는다. */
    private long ownerId() throws Exception {
        String body = mockMvc.perform(get("/api/staff"))
                .andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+),\"name\":\"[^\"]*\",\"position\":\"[^\"]*\",\"owner\":true.*", "$1"));
    }

    private long createStaff(String name, String position) throws Exception {
        String body = mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson(name, position)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        // 응답 JSON에서 id만 꺼낸다. (JSON 라이브러리 없이 단순하게)
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+).*", "$1"));
    }

    private String staffJson(String name, String position) {
        return """
                {"name":"%s","position":"%s"}
                """.formatted(name, position);
    }
}
