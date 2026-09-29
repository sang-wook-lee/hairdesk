package com.salonapp.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Swagger UI 상단에 보이는 API 문서 정보.
 * 엔드포인트 목록 자체는 springdoc이 컨트롤러를 읽어서 자동으로 만든다.
 *
 * - 문서 화면: http://localhost:8080/swagger-ui.html
 * - 원본 JSON: http://localhost:8080/v3/api-docs  (프론트/Flutter 코드 생성에도 쓸 수 있다)
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI hairdeskOpenApi() {
        return new OpenAPI().info(new Info()
                .title("hairdesk API")
                .description("1인 미용사를 위한 예약·고객·매출 관리 API")
                .version("v1"));
    }
}
