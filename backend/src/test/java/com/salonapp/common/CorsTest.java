package com.salonapp.common;

import com.salonapp.TestcontainersConfiguration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** 브라우저(Flutter 웹)가 API를 부를 수 있도록 CORS가 열려 있는지 확인한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class CorsTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @DisplayName("localhost의 어느 포트에서 온 요청이든 허용한다 (Flutter 웹은 포트가 매번 달라진다)")
    void allowsLocalhostAnyPort() throws Exception {
        mockMvc.perform(get("/api/menus").header("Origin", "http://localhost:51234"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:51234"));
    }

    @Test
    @DisplayName("브라우저가 먼저 보내는 사전 확인(preflight)에서 PATCH 같은 메서드도 허용한다")
    void allowsPreflightForPatch() throws Exception {
        mockMvc.perform(options("/api/reservations/1/time")
                        .header("Origin", "http://localhost:51234")
                        .header("Access-Control-Request-Method", "PATCH")
                        .header("Access-Control-Request-Headers", "content-type"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:51234"));
    }

    @Test
    @DisplayName("localhost가 아닌 출처는 허용하지 않는다")
    void rejectsOtherOrigins() throws Exception {
        mockMvc.perform(get("/api/menus").header("Origin", "http://evil.example.com"))
                .andExpect(status().isForbidden());
    }
}
