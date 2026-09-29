package com.salonapp.customer;

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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** 고객 카드 API 통합 테스트. 각 테스트가 ADR 0002의 결정 하나씩을 검증한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class CustomerApiTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @DisplayName("하이픈이 있는 번호로 등록해도 숫자만 저장된다")
    void normalizePhone() throws Exception {
        mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("김민지", "010-1234-5678")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.phone").value("01012345678"))
                .andExpect(jsonPath("$.smsConsent").value(false));  // 기본값: 동의 안 함
    }

    @Test
    @DisplayName("이름과 번호가 모두 같은 고객은 중복 등록할 수 없다 (409)")
    void duplicate() throws Exception {
        createCustomer("김민지", "01012345678");

        mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("김민지", "010-1234-5678")))  // 형식만 다른 같은 번호
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("번호가 같아도 이름이 다르면 등록된다 (가족이 번호를 같이 쓰는 경우)")
    void sameFamilyPhone() throws Exception {
        createCustomer("김민지", "01012345678");

        mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("박서준", "01012345678")))
                .andExpect(status().isCreated());
    }

    @Test
    @DisplayName("휴대폰 번호 형식이 아니면 400")
    void invalidPhone() throws Exception {
        mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("김민지", "02-123-4567")))  // 유선 번호
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("번호 뒷자리 4개로 검색할 수 있다")
    void searchByLastDigits() throws Exception {
        createCustomer("김민지", "01012345678");
        createCustomer("이하늘", "01099990000");

        mockMvc.perform(get("/api/customers").param("keyword", "5678"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("김민지"))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("이름 일부로 검색할 수 있다 (숫자 없는 키워드가 전체와 일치하지 않는다)")
    void searchByName() throws Exception {
        createCustomer("김민지", "01012345678");
        createCustomer("이하늘", "01099990000");

        mockMvc.perform(get("/api/customers").param("keyword", "하늘"))
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("이하늘"));
    }

    @Test
    @DisplayName("목록은 페이지 단위로 나뉜다")
    void paging() throws Exception {
        createCustomer("가나다", "01011110001");
        createCustomer("나다라", "01011110002");
        createCustomer("다라마", "01011110003");

        mockMvc.perform(get("/api/customers").param("size", "2").param("page", "1"))
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name").value("다라마"))  // 이름순 3번째
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.totalPages").value(2));
    }

    @Test
    @DisplayName("수정 시 다른 고객과 이름+번호가 겹치면 409, 자기 자신은 괜찮다")
    void updateDuplicate() throws Exception {
        createCustomer("김민지", "01012345678");
        long other = createCustomer("박서준", "01012345678");

        // 자기 자신과 같은 값으로 수정(메모만 변경) → 성공
        mockMvc.perform(put("/api/customers/{id}", other)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("박서준", "01012345678")))
                .andExpect(status().isOk());

        // 김민지와 같은 이름+번호로 수정 → 충돌
        mockMvc.perform(put("/api/customers/{id}", other)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson("김민지", "01012345678")))
                .andExpect(status().isConflict());
    }

    private long createCustomer(String name, String phone) throws Exception {
        String body = mockMvc.perform(post("/api/customers")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(customerJson(name, phone)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll(".*\"id\":(\\d+).*", "$1"));
    }

    private String customerJson(String name, String phone) {
        return """
                {"name":"%s","phone":"%s","gender":"FEMALE","memo":"두피 민감"}
                """.formatted(name, phone);
    }
}
