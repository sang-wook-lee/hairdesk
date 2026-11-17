package com.salonapp.common.config;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * "사설 네트워크 출처인가"를 판단하는 규칙만 따로 검사한다. (서버나 DB 없이 바로 돈다)
 * 이 규칙이 느슨하면 인터넷의 아무 사이트가 내 PC의 개발 서버를 부를 수 있게 되므로, 거부하는 경우를 특히 꼼꼼히 본다.
 */
class PrivateNetworkOriginTest {

    @ParameterizedTest(name = "허용: {0}")
    @DisplayName("집·사무실 안 네트워크의 IP 주소는 허용한다")
    @ValueSource(strings = {
            "http://192.168.219.108:5173",   // 집 와이파이에서 흔한 대역
            "http://192.168.0.1",            // 포트가 없어도 된다
            "http://10.0.0.5:8080",
            "http://10.255.255.255:5173",
            "http://172.16.0.1:5173",        // 172.16 ~ 172.31 이 사설 대역
            "http://172.31.255.255:5173",
    })
    void allowsPrivateAddresses(String origin) {
        assertThat(CorsConfig.isPrivateNetworkOrigin(origin)).isTrue();
    }

    @ParameterizedTest(name = "거부: {0}")
    @DisplayName("인터넷 주소, 도메인 이름, 형식이 이상한 값은 거부한다")
    @ValueSource(strings = {
            "http://8.8.8.8:5173",              // 공인 IP
            "http://172.15.0.1:5173",           // 사설 대역 바로 밖 (아래쪽)
            "http://172.32.0.1:5173",           // 사설 대역 바로 밖 (위쪽)
            "http://11.0.0.1:5173",
            "http://192.169.0.1:5173",
            "http://192.168.evil.com:5173",     // 숫자로 시작하는 "도메인 이름". 패턴으로 검사하면 뚫리는 경우
            "http://192.168.0.1.evil.com:5173",
            "http://10.0.0.1.attacker.io",
            "http://192.168.0.256:5173",        // 255 초과
            "http://192.168.0.01:5173",         // 앞에 0을 붙인 표기
            "https://192.168.0.1:5173",         // https는 허용하지 않는다 (개발용은 http)
            "http://192.168.0.1:5173/path",     // 출처에는 경로가 없다
            "http://192.168.0.1:",
            "http://localhost:5173",            // localhost는 이 규칙이 아니라 별도 패턴이 맡는다
            "null",
            "",
    })
    void rejectsOthers(String origin) {
        assertThat(CorsConfig.isPrivateNetworkOrigin(origin)).isFalse();
    }

    @org.junit.jupiter.api.Test
    @DisplayName("출처가 없으면(null) 거부한다")
    void rejectsNull() {
        assertThat(CorsConfig.isPrivateNetworkOrigin(null)).isFalse();
    }
}
