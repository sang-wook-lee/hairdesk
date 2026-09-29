package com.salonapp.menu;

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
 * 시술 메뉴 API 통합 테스트.
 * HTTP 요청 → 컨트롤러 → 서비스 → 실제 PostgreSQL(Testcontainers)까지 전부 거친다.
 * @Transactional: 테스트마다 끝나면 롤백해서 서로 데이터가 섞이지 않게 한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class TreatmentMenuApiTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @DisplayName("메뉴를 등록하면 201과 함께 생성된 메뉴를 돌려준다")
    void create() throws Exception {
        mockMvc.perform(post("/api/menus")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(menuJson("남성 커트", "CUT", 18000, 30, 1)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.name").value("남성 커트"))
                .andExpect(jsonPath("$.price").value(18000))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    @DisplayName("필수값이 빠지거나 가격이 음수면 400을 돌려준다")
    void createInvalid() throws Exception {
        mockMvc.perform(post("/api/menus")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(menuJson("", "CUT", -1000, 30, 1)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("목록은 표시 순서대로 정렬되고, 판매 중지된 메뉴는 기본적으로 빠진다")
    void listExcludesInactive() throws Exception {
        long perm = createMenu("셋팅펌", "PERM", 120000, 150, 2);
        createMenu("여성 커트", "CUT", 25000, 40, 1);
        mockMvc.perform(post("/api/menus/{id}/deactivate", perm))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/menus"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].name").value("여성 커트"));

        mockMvc.perform(get("/api/menus").param("includeInactive", "true"))
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].name").value("여성 커트"))  // displayOrder 1
                .andExpect(jsonPath("$[1].name").value("셋팅펌"));    // displayOrder 2
    }

    @Test
    @DisplayName("메뉴를 수정하면 바뀐 값이 조회된다")
    void update() throws Exception {
        long id = createMenu("뿌리염색", "COLOR", 50000, 60, 1);

        mockMvc.perform(put("/api/menus/{id}", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(menuJson("뿌리염색", "COLOR", 55000, 70, 1)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/menus/{id}", id))
                .andExpect(jsonPath("$.price").value(55000))
                .andExpect(jsonPath("$.durationMinutes").value(70));
    }

    @Test
    @DisplayName("없는 메뉴를 조회하면 404를 돌려준다")
    void notFound() throws Exception {
        mockMvc.perform(get("/api/menus/{id}", 999_999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("메뉴를 찾을 수 없습니다. id=999999"));
    }

    private long createMenu(String name, String category, int price, int duration, int order) throws Exception {
        String body = mockMvc.perform(post("/api/menus")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(menuJson(name, category, price, duration, order)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        // 응답 JSON에서 id만 꺼낸다. (JSON 라이브러리 없이 단순하게)
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+).*", "$1"));
    }

    private String menuJson(String name, String category, int price, int duration, int order) {
        return """
                {"name":"%s","category":"%s","price":%d,"durationMinutes":%d,"displayOrder":%d}
                """.formatted(name, category, price, duration, order);
    }
}
