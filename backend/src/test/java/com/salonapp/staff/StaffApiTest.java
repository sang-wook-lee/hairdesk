package com.salonapp.staff;

import com.salonapp.TestcontainersConfiguration;
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
 * 테스트마다 롤백되므로, 마이그레이션이 만든 기본 직원 "원장" 1명에서 항상 시작한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class StaffApiTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @DisplayName("직원을 등록하면 201과 함께 근무 중인 직원을 돌려주고, 응답에 owner는 없다")
    void create() throws Exception {
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "디자이너")))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.name").value("김하나"))
                .andExpect(jsonPath("$.position").value("디자이너"))
                .andExpect(jsonPath("$.owner").doesNotExist())
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("등록 요청에 owner·active를 실어 보내도 무시되고 근무 중인 직원으로 등록된다")
    void createIgnoresExtraFields() throws Exception {
        mockMvc.perform(post("/api/staff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"김하나","position":"원장","owner":true,"active":false}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.owner").doesNotExist())
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
    @DisplayName("이름과 직책을 수정하면 바뀐 값이 조회되고, 근무 여부는 그대로다")
    void update() throws Exception {
        long id = createStaff("김하나", "디자이너");

        mockMvc.perform(put("/api/staff/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "실장")))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/staff/{id}", id))
                .andExpect(jsonPath("$.position").value("실장"))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("없는 직원 번호로 조회·수정·근무 종료·재개를 하면 404를 돌려준다")
    void notFound() throws Exception {
        mockMvc.perform(get("/api/staff/{id}", 999_999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("직원을 찾을 수 없습니다. 직원 번호=999999"));
        mockMvc.perform(put("/api/staff/{id}", 999_999)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(staffJson("김하나", "실장")))
                .andExpect(status().isNotFound());
        mockMvc.perform(post("/api/staff/{id}/deactivate", 999_999)).andExpect(status().isNotFound());
        mockMvc.perform(post("/api/staff/{id}/activate", 999_999)).andExpect(status().isNotFound());
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
    @DisplayName("원장도 다른 직원과 같은 규칙이다: 마지막 근무 직원도 근무를 종료할 수 있고, 재개하면 돌아온다")
    void lastActiveStaffCanBeDeactivatedAndReactivated() throws Exception {
        long director = firstStaffId(); // 마이그레이션이 만든 원장. 지금 근무 중인 유일한 직원

        mockMvc.perform(post("/api/staff/{id}/deactivate", director)).andExpect(status().isNoContent());
        mockMvc.perform(get("/api/staff")).andExpect(jsonPath("$", hasSize(0)));

        mockMvc.perform(post("/api/staff/{id}/activate", director)).andExpect(status().isNoContent());
        mockMvc.perform(get("/api/staff")).andExpect(jsonPath("$", hasSize(1)));
    }

    @Test
    @DisplayName("직책이 원장인 직원을 여러 명 등록할 수 있다")
    void severalDirectors() throws Exception {
        createStaff("이지수", "원장");
        createStaff("박민수", "원장");

        mockMvc.perform(get("/api/staff"))
                .andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[?(@.position == '원장')]", hasSize(3)));
    }

    @Test
    @DisplayName("주인 지정 API(make-owner)는 없다 (ADR 0011)")
    void makeOwnerEndpointIsGone() throws Exception {
        long id = createStaff("이지수", "원장");

        mockMvc.perform(post("/api/staff/{id}/make-owner", id)).andExpect(status().is4xxClientError());
    }

    /** 목록의 첫 직원(직원 번호가 가장 작은 사람)의 번호. 테스트마다 마이그레이션이 만든 "원장"이다. */
    private long firstStaffId() throws Exception {
        String body = mockMvc.perform(get("/api/staff"))
                .andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll("^\\[\\{\"id\":(\\d+).*$", "$1"));
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
