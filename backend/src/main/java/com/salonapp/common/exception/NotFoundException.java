package com.salonapp.common.exception;

/** 요청한 데이터가 없을 때. GlobalExceptionHandler가 404로 바꿔 응답한다. */
public class NotFoundException extends RuntimeException {

    public NotFoundException(String message) {
        super(message);
    }
}
