package com.salonapp.customer.domain;

import com.salonapp.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.regex.Pattern;

/**
 * 고객 카드. 식별 규칙과 개인정보 정책은 ADR 0002 참고.
 */
@Entity
@Table(name = "customer")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Customer extends BaseTimeEntity {

    /** 숫자만 남긴 한국 휴대폰 번호: 010, 011, 016, 017, 018, 019 + 7~8자리 */
    private static final Pattern MOBILE_PHONE = Pattern.compile("^01[016789]\\d{7,8}$");

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 30)
    private String name;

    @Column(nullable = false, length = 11)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Gender gender;

    @Column(length = 1000)
    private String memo;

    @Column(name = "sms_consent", nullable = false)
    private boolean smsConsent;

    public Customer(String name, String phone, Gender gender, String memo, boolean smsConsent) {
        update(name, phone, gender, memo, smsConsent);
    }

    public void update(String name, String phone, Gender gender, String memo, boolean smsConsent) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("고객 이름은 필수입니다.");
        }
        this.name = name.strip();
        this.phone = normalizePhone(phone);
        this.gender = gender;
        this.memo = (memo == null || memo.isBlank()) ? null : memo.strip();
        this.smsConsent = smsConsent;
    }

    /**
     * "010-1234-5678", "010 1234 5678" → "01012345678"
     * 저장 형식을 하나로 통일해야 중복 체크와 검색이 정확해진다.
     * 서비스에서 중복 체크할 때도 같은 규칙을 써야 하므로 public static으로 연다.
     */
    public static String normalizePhone(String rawPhone) {
        if (rawPhone == null) {
            throw new IllegalArgumentException("휴대폰 번호는 필수입니다.");
        }
        String digits = rawPhone.replaceAll("\\D", "");
        if (!MOBILE_PHONE.matcher(digits).matches()) {
            throw new IllegalArgumentException("올바른 휴대폰 번호가 아닙니다: " + rawPhone);
        }
        return digits;
    }
}
