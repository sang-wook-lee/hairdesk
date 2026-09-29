package com.salonapp.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * 예외를 HTTP 응답으로 바꾸는 한 곳.
 *
 * 응답 형식은 표준(RFC 9457) ProblemDetail을 쓴다. 예:
 * { "status": 404, "title": "Not Found", "detail": "메뉴를 찾을 수 없습니다. id=99" }
 *
 * ResponseEntityExceptionHandler를 상속하면 @Valid 검증 실패(400) 같은
 * 스프링 기본 예외도 같은 형식으로 응답된다.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ProblemDetail handleNotFound(NotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    /** 엔티티의 규칙 검증에 걸린 경우 (예: 음수 가격) */
    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleIllegalArgument(IllegalArgumentException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, e.getMessage());
    }
}
