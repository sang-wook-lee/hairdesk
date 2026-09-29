package com.salonapp.common.dto;

import org.springframework.data.domain.Page;

import java.util.List;

/**
 * 페이지 응답 형식.
 * Spring의 Page 객체를 그대로 내보내면 내부 구조(pageable, sort 등)가 전부 노출되고,
 * 라이브러리 버전에 따라 형식이 바뀔 수 있다. 그래서 필요한 필드만 담은 고정 형식을 쓴다.
 *
 * @param page 0부터 시작하는 페이지 번호
 */
public record PageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages
) {
    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(
                page.getContent(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages()
        );
    }
}
