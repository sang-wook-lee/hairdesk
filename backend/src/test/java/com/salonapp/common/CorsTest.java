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

/** 브라우저(Flutter 웹)가 API를 부를 수 있도록 CORS가 열려 있는지, 그리고 엉뚱한 출처는 막히는지 확인한다. (ADR 0009) */
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
    @DisplayName("집 안 네트워크의 사설 IP 출처도 허용한다 (폰 브라우저로 PC의 앱을 열어 볼 때)")
    void allowsPrivateNetworkOrigins() throws Exception {
        for (String origin : new String[]{"http://192.168.219.108:5173", "http://10.0.0.5:5173", "http://172.20.1.1:5173"}) {
            mockMvc.perform(get("/api/menus").header("Origin", origin))
                    .andExpect(status().isOk())
                    .andExpect(header().string("Access-Control-Allow-Origin", origin));
        }
    }

    @Test
    @DisplayName("사설 IP 출처에서도 preflight(PATCH)가 통과한다")
    void allowsPreflightFromPrivateNetwork() throws Exception {
        mockMvc.perform(options("/api/reservations/1/time")
                        .header("Origin", "http://192.168.219.108:5173")
                        .header("Access-Control-Request-Method", "PATCH")
                        .header("Access-Control-Request-Headers", "content-type"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://192.168.219.108:5173"));
    }

    @Test
    @DisplayName("localhost와 사설 IP가 아닌 출처는 허용하지 않는다")
    void rejectsOtherOrigins() throws Exception {
        for (String origin : new String[]{
                "http://evil.example.com",
                "http://8.8.8.8:5173",
                "http://172.32.0.1:5173",
                "http://192.168.evil.com:5173"}) {
            mockMvc.perform(get("/api/menus").header("Origin", origin))
                    .andExpect(status().isForbidden());
        }
    }

    @Test
    @DisplayName("Origin 헤더가 없는 요청(curl, 서버끼리 호출)은 CORS와 무관하게 통과한다")
    void requestsWithoutOriginPass() throws Exception {
        mockMvc.perform(get("/api/menus"))
                .andExpect(status().isOk());
    }
}
