package com.salonapp.common.exception;

/** 이미 존재하는 데이터와 충돌할 때 (예: 중복 고객). GlobalExceptionHandler가 409로 바꿔 응답한다. */
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
