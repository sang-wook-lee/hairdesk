package com.salonapp.common.dev;

import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.domain.Gender;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.reservation.domain.Reservation;
import com.salonapp.reservation.repository.ReservationRepository;
import com.salonapp.sales.domain.PaymentMethod;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * 개발용 샘플 데이터. 서버가 켜질 때 DB가 "비어 있으면" 채운다.
 *
 * - "local" 프로필에서만 동작한다. (./gradlew bootRun 이 켜 준다. 테스트와 운영에는 절대 돌지 않는다)
 * - 메뉴나 고객이 하나라도 있으면 아무것도 하지 않는다. 그래서 매번 켜도 중복되지 않고, 직접 넣은 데이터도 안전하다.
 * - 날짜는 "오늘 기준 상대 날짜"다: 과거 60일 이력 + 앞으로 일주일 예약. 며칠 뒤에 켜도 홈 화면이 비지 않는다.
 * - 엔티티와 DB 제약을 그대로 거치므로, 서비스 규칙(예약 겹침 불가 등)에 어긋난 가짜 데이터는 들어가지 않는다.
 * - 난수는 고정 시드라서, 같은 날 새로 채우면 항상 같은 모양이 나온다.
 *
 * 처음부터 다시 채우고 싶으면: backend/ 에서 `docker compose down -v` (개발 DB의 모든 데이터가 지워진다) 후 bootRun.
 */
@Slf4j
@Component
@Profile("local")
@RequiredArgsConstructor
public class DevDataSeeder implements ApplicationRunner {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    /** 하루 3타임. 가장 긴 시술(3시간)도 다음 타임 시작과 딱 맞닿을 뿐 겹치지 않는다. */
    private static final int[] SLOT_HOURS = {10, 13, 16};

    private static final int HISTORY_DAYS = 60;
    private static final int FUTURE_DAYS = 7;

    private static final String[] MEMOS = {"뿌리 볼륨 원함", "두피 민감", "지난번보다 짧게", "앞머리 포함", "염색 알레르기 주의"};

    private final TreatmentMenuRepository menuRepository;
    private final CustomerRepository customerRepository;
    private final ReservationRepository reservationRepository;
    private final SaleRepository saleRepository;
    private final StaffRepository staffRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (menuRepository.count() > 0 || customerRepository.count() > 0) {
            log.info("개발용 샘플 데이터: 이미 데이터가 있어 건너뜁니다.");
            return;
        }
        seed(Instant.now());
    }

    private void seed(Instant now) {
        Random random = new Random(42);
        List<TreatmentMenu> menus = seedMenus();
        List<Customer> customers = seedCustomers();
        // TODO(직원 5단계): 직원 여러 명을 만들어 나눠 배정한다. 그 전까지는 모두 매장 주인(원장)이 담당한다.
        Staff owner = staffRepository.findByOwnerTrue().orElseThrow();
        List<TreatmentMenu> sellable = menus.stream().filter(TreatmentMenu::isActive).toList();

        LocalDate today = now.atZone(SEOUL).toLocalDate();
        int reservations = 0;
        for (int offset = -HISTORY_DAYS; offset <= FUTURE_DAYS; offset++) {
            LocalDate day = today.plusDays(offset);
            if (day.getDayOfWeek() == DayOfWeek.SUNDAY) {
                continue; // 일요일은 쉰다
            }
            for (int hour : SLOT_HOURS) {
                // 과거일수록 바쁘고(65%), 미래는 절반쯤 찼다고 본다(50%)
                int fillRate = offset < 0 ? 65 : 50;
                if (random.nextInt(100) >= fillRate) {
                    continue; // 빈 타임
                }
                TreatmentMenu menu = sellable.get(random.nextInt(sellable.size()));
                Customer customer = pickCustomer(customers, -offset, random);
                Instant start = day.atTime(hour, 0).atZone(SEOUL).toInstant();
                Reservation reservation = new Reservation(
                        customer, menu, owner, start, random.nextInt(100) < 15 ? MEMOS[random.nextInt(MEMOS.length)] : null);
                settle(reservation, now, random);
                reservations++;
            }
        }
        log.info("개발용 샘플 데이터를 넣었습니다: 메뉴 {}개, 고객 {}명, 예약 {}건 (오늘 기준 과거 {}일 ~ 앞으로 {}일)",
                menus.size(), customers.size(), reservations, HISTORY_DAYS, FUTURE_DAYS);
    }

    /**
     * 예약을 저장하고, 이미 지난 예약이면 결과(완료+결제 / 취소 / 노쇼)를 정해 준다.
     * 아직 안 끝난 예약(오늘 남은 타임, 미래)은 "예약" 상태로 둔다.
     */
    private void settle(Reservation reservation, Instant now, Random random) {
        boolean finished = !reservation.getEndAt().isAfter(now);
        if (!finished) {
            reservationRepository.saveAndFlush(reservation);
            return;
        }
        int outcome = random.nextInt(100);
        if (outcome < 6) {
            reservation.cancel();
        } else if (outcome < 12) {
            reservation.markNoShow();
        } else {
            reservation.complete();
        }
        reservationRepository.saveAndFlush(reservation);

        if (outcome >= 12) { // 완료된 예약만 결제가 있다
            TreatmentMenu menu = reservation.getMenu();
            int discount = random.nextInt(100) < 10 ? 2000 : 0; // 10%는 2천 원 할인
            saleRepository.save(Sale.forReservation(
                    reservation, menu.getPrice() - discount, pickPaymentMethod(random), reservation.getEndAt(), null));
        }
    }

    /**
     * 오래전에는 "단골 8명"만 오고, 최근 3주부터 "신규 4명"도 나타난다.
     * 그래야 통계의 신규/재방문 고객 수가 의미 있는 값으로 나온다.
     */
    private Customer pickCustomer(List<Customer> customers, int daysAgo, Random random) {
        int pool = daysAgo > 21 ? 8 : customers.size();
        return customers.get(random.nextInt(pool));
    }

    private PaymentMethod pickPaymentMethod(Random random) {
        int roll = random.nextInt(100);
        if (roll < 60) {
            return PaymentMethod.CARD;
        }
        return roll < 85 ? PaymentMethod.CASH : PaymentMethod.TRANSFER;
    }

    private List<TreatmentMenu> seedMenus() {
        List<TreatmentMenu> menus = new ArrayList<>(List.of(
                new TreatmentMenu("남성 커트", MenuCategory.CUT, 15000, 40, 1),
                new TreatmentMenu("여성 커트", MenuCategory.CUT, 25000, 60, 2),
                new TreatmentMenu("일반 펌", MenuCategory.PERM, 80000, 150, 3),
                new TreatmentMenu("셋팅 펌", MenuCategory.PERM, 110000, 180, 4),
                new TreatmentMenu("뿌리 염색", MenuCategory.COLOR, 50000, 90, 5),
                new TreatmentMenu("전체 염색", MenuCategory.COLOR, 90000, 150, 6),
                new TreatmentMenu("두피 클리닉", MenuCategory.CLINIC, 40000, 60, 7)));
        TreatmentMenu ended = new TreatmentMenu("가을 이벤트 펌", MenuCategory.PERM, 60000, 150, 8);
        ended.deactivate(); // 판매 중지된 메뉴도 하나 있어야 "판매 중지 포함" 화면을 볼 수 있다
        menus.add(ended);
        return menuRepository.saveAll(menus);
    }

    private List<Customer> seedCustomers() {
        // 번호는 한눈에 가짜로 보이는 010-5550-00NN 형식
        String[][] people = {
                // 단골 8명 (앞 8명)
                {"김민지", "F", "두피 민감"}, {"이하늘", "F", "염색 알레르기 주의"}, {"박서준", "M", null},
                {"최유리", "F", "앞머리 관리 원함"}, {"정다은", "F", null}, {"한지우", "M", null},
                {"오세훈", "M", "짧은 스타일 선호"}, {"윤소희", "F", null},
                // 신규 4명 (최근 3주부터 등장)
                {"장민호", "M", null}, {"임나연", "F", "지인 소개"}, {"강예린", "F", null}, {"송하준", "M", null},
        };
        List<Customer> customers = new ArrayList<>();
        for (int i = 0; i < people.length; i++) {
            String phone = String.format("010555%05d", i + 1);
            Gender gender = "F".equals(people[i][1]) ? Gender.FEMALE : Gender.MALE;
            customers.add(new Customer(people[i][0], phone, gender, people[i][2], i % 3 == 0)); // 3명 중 1명만 문자 수신 동의
        }
        return customerRepository.saveAll(customers);
    }
}
