package com.salonapp.common.domain;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

/**
 * 모든 엔티티가 공통으로 갖는 생성/수정 시각.
 * 저장(INSERT) 시 createdAt, 변경(UPDATE) 시 updatedAt을 Hibernate가 자동으로 채운다.
 *
 * Instant = 시간대 없는 "절대 시각". DB의 timestamptz와 짝이 맞고,
 * 화면에 보여줄 때만 Asia/Seoul로 변환한다.
 */
@Getter
@MappedSuperclass
public abstract class BaseTimeEntity {

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
