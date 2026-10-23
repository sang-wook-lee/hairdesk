package com.salonapp.common.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 개발 중 브라우저(Flutter 웹)에서 API를 부를 수 있게 허용한다.
 *
 * CORS란: 브라우저는 "다른 출처(주소+포트)"의 서버로 보내는 요청을 기본으로 막는다.
 * Flutter 웹은 localhost:51234 같은 임의 포트에서 뜨고 API는 localhost:8080이라 서로 다른 출처다.
 * 서버가 "이 출처는 괜찮다"고 응답 헤더로 알려줘야 브라우저가 통과시킨다.
 * (모바일 앱은 브라우저가 아니라서 CORS와 무관하다)
 *
 * 지금은 localhost 출처만 허용한다. 운영 배포 때는 실제 웹 주소로 좁혀야 한다.
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns("http://localhost:*", "http://127.0.0.1:*")
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS");
    }
}
