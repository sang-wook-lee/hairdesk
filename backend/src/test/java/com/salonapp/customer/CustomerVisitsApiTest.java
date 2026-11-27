package com.salonapp.customer;

import com.salonapp.TestcontainersConfiguration;
import com.salonapp.customer.domain.Customer;
import com.salonapp.customer.repository.CustomerRepository;
import com.salonapp.menu.domain.MenuCategory;
import com.salonapp.menu.domain.TreatmentMenu;
import com.salonapp.menu.repository.TreatmentMenuRepository;
import com.salonapp.sales.domain.PaymentMethod;
import com.salonapp.sales.domain.Sale;
import com.salonapp.sales.repository.SaleRepository;
import com.salonapp.staff.domain.Staff;
import com.salonapp.staff.repository.StaffRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /api/customers/{id}/visits 통합 테스트. (고객의 방문 이력 = 매출 기록, 최신순, 페이징)
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
@Transactional
class CustomerVisitsApiTest {

    @Autowired MockMvc mockMvc;
    @Autowired CustomerRepository customerRepository;
    @Autowired TreatmentMenuRepository menuRepository;
    @Autowired SaleRepository saleRepository;
    @Autowired StaffRepository staffRepository;

    Staff director;      // V6 마이그레이션이 만든 기본 직원(원장)
    Staff jisoo;
    Customer minji;
    Customer haneul;
    TreatmentMenu cut;
    TreatmentMenu perm;

    @BeforeEach
    void setUp() {
        director = staffRepository.findAllByOrderByIdAsc().get(0);
        jisoo = staffRepository.save(new Staff("이지수", "실장"));
        minji = customerRepository.save(new Customer("김민지", "01012345678", null, null, false));
        haneul = customerRepository.save(new Customer("이하늘", "01099990000", null, null, false));
        cut = menuRepository.save(new TreatmentMenu("커트", MenuCategory.CUT, 20000, 60, 1));
        perm = menuRepository.save(new TreatmentMenu("펌", MenuCategory.PERM, 80000, 120, 2));
    }

    @Test
    @DisplayName("결제 시각이 가장 최근인 방문이 먼저 나온다 (저장한 순서가 아니다)")
    void newestFirst() throws Exception {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");   // 나중에 저장했지만 가장 최근
        sell(minji, cut, director, 18000, "2026-10-10T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/visits", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(3))
                .andExpect(jsonPath("$.content[0].paidAt").value("2026-10-20T10:00:00+09:00"))
                .andExpect(jsonPath("$.content[1].paidAt").value("2026-10-10T10:00:00+09:00"))
                .andExpect(jsonPath("$.content[2].paidAt").value("2026-10-01T10:00:00+09:00"));
    }

    @Test
    @DisplayName("결제 시각이 같으면 번호가 큰(나중에 저장한) 방문이 먼저 나온다")
    void sameTimeLargerIdFirst() throws Exception {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(minji, perm, jisoo, 80000, "2026-10-01T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/visits", minji.getId()))
                .andExpect(jsonPath("$.content[0].menuName").value("펌"))
                .andExpect(jsonPath("$.content[1].menuName").value("커트"));
    }

    @Test
    @DisplayName("다른 고객의 매출은 섞이지 않는다")
    void doesNotMixCustomers() throws Exception {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(haneul, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/visits", minji.getId()))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].customerId").value(minji.getId()));
    }

    @Test
    @DisplayName("페이지 크기대로 나뉘고, 전체 개수와 페이지 수가 맞다")
    void paging() throws Exception {
        for (int day = 1; day <= 5; day++) {
            sell(minji, cut, director, 20000, "2026-10-0" + day + "T10:00:00+09:00");
        }

        mockMvc.perform(get("/api/customers/{id}/visits?page=1&size=2", minji.getId()))
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.size").value(2))
                .andExpect(jsonPath("$.totalElements").value(5))
                .andExpect(jsonPath("$.totalPages").value(3))
                // 최신순 5,4 | 3,2 | 1 → 두 번째 페이지는 3일, 2일
                .andExpect(jsonPath("$.content[0].paidAt").value("2026-10-03T10:00:00+09:00"))
                .andExpect(jsonPath("$.content[1].paidAt").value("2026-10-02T10:00:00+09:00"));
    }

    @Test
    @DisplayName("방문이 없는 고객은 200과 빈 목록을 준다")
    void noVisitsIsEmpty() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/visits", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    @DisplayName("없는 고객은 404와 안내 메시지를 준다")
    void unknownCustomerIs404() throws Exception {
        mockMvc.perform(get("/api/customers/{id}/visits", 999999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("고객을 찾을 수 없습니다. id=999999"));
    }

    @Test
    @DisplayName("담당 직원의 번호·이름·직책과 받은 금액이 응답에 들어 있다")
    void includesStaffAndAmount() throws Exception {
        sell(minji, perm, jisoo, 70000, "2026-10-20T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/visits", minji.getId()))
                .andExpect(jsonPath("$.content[0].staffId").value(jisoo.getId()))
                .andExpect(jsonPath("$.content[0].staffName").value("이지수"))
                .andExpect(jsonPath("$.content[0].staffPosition").value("실장"))
                .andExpect(jsonPath("$.content[0].menuName").value("펌"))
                .andExpect(jsonPath("$.content[0].price").value(80000))
                .andExpect(jsonPath("$.content[0].amount").value(70000));
    }

    @Test
    @DisplayName("sort 파라미터는 무시한다 (없는 필드를 보내도 오류 없이 최신순으로 나온다)")
    void sortParameterIsIgnored() throws Exception {
        sell(minji, cut, director, 20000, "2026-10-01T10:00:00+09:00");
        sell(minji, perm, jisoo, 80000, "2026-10-20T10:00:00+09:00");

        mockMvc.perform(get("/api/customers/{id}/visits?sort=noSuchField,asc", minji.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].paidAt").value("2026-10-20T10:00:00+09:00"));
    }

    // ---- 도우미 ----

    private Instant at(String iso) {
        return OffsetDateTime.parse(iso).toInstant();
    }

    private void sell(Customer customer, TreatmentMenu menu, Staff staff, int amount, String paidAt) {
        saleRepository.saveAndFlush(Sale.walkIn(customer, menu, staff, amount, PaymentMethod.CARD, at(paidAt), null));
    }
}
