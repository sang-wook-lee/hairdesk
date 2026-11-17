package com.salonapp.common.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 개발 중 브라우저(Flutter 웹)에서 API를 부를 수 있게 허용한다. (ADR 0009)
 *
 * CORS란: 브라우저는 "다른 출처(주소+포트)"의 서버로 보내는 요청을 기본으로 막는다.
 * Flutter 웹은 localhost:51234 같은 임의 포트에서 뜨고 API는 localhost:8080이라 서로 다른 출처다.
 * 서버가 "이 출처는 괜찮다"고 응답 헤더로 알려줘야 브라우저가 통과시킨다.
 * (모바일 앱은 브라우저가 아니라서 CORS와 무관하다)
 *
 * 허용하는 출처는 두 가지다.
 *  1) localhost / 127.0.0.1 (내 PC에서 개발할 때)
 *  2) 집·사무실 안 네트워크의 사설 IP 주소 (폰 브라우저로 PC의 앱을 열어 볼 때. 예: http://192.168.219.108:5173)
 * 인터넷의 다른 주소와 도메인 이름은 허용하지 않는다. 운영 배포 때는 실제 웹 주소 하나로 좁혀야 한다.
 */
@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new PrivateNetworkCorsConfiguration();
        config.setAllowedOriginPatterns(List.of("http://localhost:*", "http://127.0.0.1:*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setMaxAge(1800L); // 사전 확인(preflight) 결과를 브라우저가 30분 기억하게 한다

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return new CorsFilter(source);
    }

    /** 기본 규칙(localhost 패턴)에 더해, 사설 IP 주소 출처도 허용하는 CORS 설정. */
    static class PrivateNetworkCorsConfiguration extends CorsConfiguration {

        /** 허용하면 그 출처 문자열을, 거부하면 null을 돌려준다. (부모 클래스의 약속) */
        @Override
        public String checkOrigin(String requestOrigin) {
            String allowed = super.checkOrigin(requestOrigin);
            if (allowed != null) {
                return allowed;
            }
            return isPrivateNetworkOrigin(requestOrigin) ? requestOrigin : null;
        }
    }

    /** 0~255 사이의 숫자 하나. 앞에 0을 붙인 값(010)이나 256 이상은 통과하지 못한다. */
    private static final String OCTET = "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)";

    /** "http://숫자.숫자.숫자.숫자" 또는 뒤에 ":포트"가 붙은 형태만 통과한다. 도메인 이름은 통과하지 못한다. */
    private static final Pattern IPV4_ORIGIN = Pattern.compile(
            "^http://" + OCTET + "\\." + OCTET + "\\." + OCTET + "\\." + OCTET + "(?::\\d{1,5})?$");

    /**
     * 출처가 "사설 네트워크의 IPv4 주소"인가.
     * 사설 대역: 10.0.0.0/8, 172.16.0.0/12 (172.16~172.31), 192.168.0.0/16. 인터넷에서는 쓰이지 않는 주소 범위다.
     *
     * 패턴(http://192.168.*)이 아니라 숫자를 직접 읽어서 검사하는 이유:
     * 패턴의 *는 아무 글자와 일치해서 "192.168.evil.com" 같은 도메인 이름까지 통과시켜 버린다.
     */
    public static boolean isPrivateNetworkOrigin(String origin) {
        if (origin == null) {
            return false;
        }
        Matcher matcher = IPV4_ORIGIN.matcher(origin);
        if (!matcher.matches()) {
            return false;
        }
        int first = Integer.parseInt(matcher.group(1));
        int second = Integer.parseInt(matcher.group(2));
        return first == 10
                || (first == 172 && second >= 16 && second <= 31)
                || (first == 192 && second == 168);
    }
}
