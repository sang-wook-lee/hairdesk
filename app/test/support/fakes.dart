// 테스트에서 서버 대신 쓰는 가짜 저장소 모음.
// 실제 저장소를 implements하면 같은 메서드를 직접 채워야 해서, 화면이 어떤 기능을 쓰는지 한눈에 보인다.
// 화면 테스트마다 같은 가짜를 복사하지 않도록 여기 한 곳에 둔다.

import 'dart:async';

import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/core/kst.dart';
import 'package:hairdesk/features/customer/customer.dart';
import 'package:hairdesk/features/customer/customer_repository.dart';
import 'package:hairdesk/features/menu/menu.dart';
import 'package:hairdesk/features/menu/menu_repository.dart';
import 'package:hairdesk/features/reservation/reservation.dart';
import 'package:hairdesk/features/reservation/reservation_repository.dart';
import 'package:hairdesk/features/sales/sale.dart';
import 'package:hairdesk/features/sales/sale_repository.dart';
import 'package:hairdesk/features/stats/stats.dart';
import 'package:hairdesk/features/stats/stats_repository.dart';

// ---------------------------------------------------------------- 메뉴

class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository(this.menus);

  final List<Menu> menus;
  final List<MenuInput> created = [];
  ApiException? failOnCreate;

  @override
  Future<List<Menu>> fetchAll({bool includeInactive = false}) async {
    return menus.where((m) => includeInactive || m.active).toList();
  }

  @override
  Future<Menu> create(MenuInput input) async {
    if (failOnCreate != null) throw failOnCreate!;
    created.add(input);
    final menu = Menu(
      id: menus.length + 1,
      name: input.name,
      category: input.category,
      price: input.price,
      durationMinutes: input.durationMinutes,
      active: true,
      displayOrder: input.displayOrder,
    );
    menus.add(menu);
    return menu;
  }

  @override
  Future<Menu> update(int id, MenuInput input) async => throw UnimplementedError();

  @override
  Future<void> setActive(int id, {required bool active}) async {
    final index = menus.indexWhere((m) => m.id == id);
    final old = menus[index];
    menus[index] = Menu(
      id: old.id,
      name: old.name,
      category: old.category,
      price: old.price,
      durationMinutes: old.durationMinutes,
      active: active,
      displayOrder: old.displayOrder,
    );
  }
}

Menu menuOf(int id, String name, {int price = 20000, int minutes = 60, bool active = true}) {
  return Menu(
    id: id,
    name: name,
    category: MenuCategory.cut,
    price: price,
    durationMinutes: minutes,
    active: active,
    displayOrder: id,
  );
}

// ---------------------------------------------------------------- 고객

class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository(this.customers);

  final List<Customer> customers;
  final List<String> searches = []; // 서버로 간 검색어 기록
  final List<CustomerInput> created = [];
  ApiException? failOnCreate;

  @override
  Future<List<Customer>> search(String keyword) async {
    searches.add(keyword.trim());
    final k = keyword.trim();
    if (k.isEmpty) return List.of(customers);
    return customers.where((c) => c.name.contains(k) || c.phone.contains(k)).toList();
  }

  @override
  Future<Customer> create(CustomerInput input) async {
    if (failOnCreate != null) throw failOnCreate!;
    created.add(input);
    final customer = Customer(
      id: 100 + created.length,
      name: input.name,
      phone: input.phone.replaceAll(RegExp(r'\D'), ''), // 서버처럼 숫자만 남긴다
      memo: input.memo,
    );
    customers.add(customer);
    return customer;
  }
}

Customer customerOf(int id, String name, String phone, {String? memo}) =>
    Customer(id: id, name: name, phone: phone, memo: memo);

// ---------------------------------------------------------------- 예약

class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository(this.reservations, {this.customers = const [], this.menus = const []});

  final List<Reservation> reservations;

  /// 예약 등록 응답에 이름을 채우려고 쓰는 목록 (서버가 id로 이름을 찾아 주는 것을 흉내 낸다)
  final List<Customer> customers;
  final List<Menu> menus;

  final List<String> requestedDates = []; // 조회 요청 기록 "2026-10-01~2026-10-01"
  final List<Map<String, Object?>> created = []; // 등록 요청 기록
  ApiException? failWith; // 조회 실패
  Object? failOnCreate; // 등록 실패. ApiException(예: 409)이나 일반 예외(네트워크 오류)
  Object? failOnChange; // 시간 변경/취소/노쇼 실패
  final List<String> changes = []; // 상태 변경 요청 기록: "cancel:1", "no-show:2", "reschedule:3:2026-10-01T11:00:00+09:00"

  @override
  Future<List<Reservation>> fetchBetween(DateTime from, DateTime to) async {
    requestedDates.add('${formatIsoDate(from)}~${formatIsoDate(to)}');
    if (failWith != null) throw failWith!;
    return reservations.where((r) {
      final day = toKst(r.startAt);
      final d = DateTime(day.year, day.month, day.day);
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  @override
  Future<Reservation> reschedule(int id, DateTime startAt) async {
    if (failOnChange != null) throw failOnChange!;
    final iso = formatKstIso(startAt);
    changes.add('reschedule:$id:$iso');
    final newStart = DateTime.parse(iso);
    return _replace(id, (r) => _copy(r, startAt: newStart, endAt: newStart.add(r.endAt.difference(r.startAt))));
  }

  @override
  Future<Reservation> cancel(int id) async {
    if (failOnChange != null) throw failOnChange!;
    changes.add('cancel:$id');
    return _replace(id, (r) => _copy(r, status: ReservationStatus.cancelled));
  }

  @override
  Future<Reservation> markNoShow(int id) async {
    if (failOnChange != null) throw failOnChange!;
    changes.add('no-show:$id');
    return _replace(id, (r) => _copy(r, status: ReservationStatus.noShow));
  }

  /// 결제가 등록되면 서버가 예약을 완료 처리하는 것을 흉내 낸다. (FakeSaleRepository가 부른다)
  void markCompleted(int id) => _replace(id, (r) => _copy(r, status: ReservationStatus.completed));

  Reservation _replace(int id, Reservation Function(Reservation) change) {
    final index = reservations.indexWhere((r) => r.id == id);
    final updated = change(reservations[index]);
    reservations[index] = updated;
    return updated;
  }

  Reservation _copy(Reservation r, {ReservationStatus? status, DateTime? startAt, DateTime? endAt}) {
    return Reservation(
      id: r.id,
      customerId: r.customerId,
      customerName: r.customerName,
      customerPhone: r.customerPhone,
      menuId: r.menuId,
      menuName: r.menuName,
      startAt: startAt ?? r.startAt,
      endAt: endAt ?? r.endAt,
      status: status ?? r.status,
      memo: r.memo,
    );
  }

  @override
  Future<Reservation> create({
    required int customerId,
    required int menuId,
    required DateTime startAt,
    String? memo,
  }) async {
    if (failOnCreate != null) throw failOnCreate!;
    final customer = customers.firstWhere((c) => c.id == customerId);
    final menu = menus.firstWhere((m) => m.id == menuId);
    final iso = formatKstIso(startAt);
    created.add({'customerId': customerId, 'menuId': menuId, 'startAt': iso, 'memo': memo});

    final start = DateTime.parse(iso);
    final reservation = Reservation(
      id: reservations.length + 1,
      customerId: customerId,
      customerName: customer.name,
      customerPhone: customer.phone,
      menuId: menuId,
      menuName: menu.name,
      startAt: start,
      endAt: start.add(Duration(minutes: menu.durationMinutes)),
      status: ReservationStatus.booked,
      memo: memo,
    );
    reservations.add(reservation);
    return reservation;
  }
}

Reservation reservationOf(
  int id,
  String customer,
  String menu,
  String start,
  String end, {
  ReservationStatus status = ReservationStatus.booked,
  String? memo,
}) {
  return Reservation(
    id: id,
    customerId: id,
    customerName: customer,
    customerPhone: '01012345678',
    menuId: 1,
    menuName: menu,
    startAt: DateTime.parse(start),
    endAt: DateTime.parse(end),
    status: status,
    memo: memo,
  );
}

// ---------------------------------------------------------------- 매출

class FakeSaleRepository implements SaleRepository {
  /// [reservations]를 주면 결제 등록 때 그 예약을 완료 처리한다 (서버의 "결제 = 완료" 동작).
  FakeSaleRepository({this.reservations, this.ledger = const []});

  final FakeReservationRepository? reservations;

  /// 매출 요약 테스트용 장부: (날짜, 금액) 목록. 서울 기준 날짜로 쓴다.
  final List<({DateTime date, int amount})> ledger;
  Object? failOnSummary;
  final List<String> summaryRequests = []; // 요약 요청 기록 "2026-11-01~2026-11-30"
  final List<Map<String, Object?>> created = [];
  Object? failOnCreate;

  @override
  Future<Sale> create({
    required int reservationId,
    required int amount,
    required PaymentMethod method,
    String? memo,
  }) async {
    if (failOnCreate != null) throw failOnCreate!;
    created.add({'reservationId': reservationId, 'amount': amount, 'method': method, 'memo': memo});
    reservations?.markCompleted(reservationId);
    return Sale(id: created.length, price: amount, amount: amount, paymentMethod: method);
  }

  @override
  Future<SalesSummary> summarize(DateTime from, DateTime to) async {
    summaryRequests.add('${formatIsoDate(from)}~${formatIsoDate(to)}');
    if (failOnSummary != null) throw failOnSummary!;
    final inRange = ledger.where((s) => !s.date.isBefore(from) && !s.date.isAfter(to));
    return SalesSummary(
      totalAmount: inRange.fold(0, (sum, s) => sum + s.amount),
      count: inRange.length,
    );
  }
}

// ---------------------------------------------------------------- 통계

/// 정해진 통계 값을 돌려주는 가짜 저장소. 어떤 기간으로 불렀는지도 기록한다.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    this.daily = const [],
    this.menus = const [],
    this.customers = const CustomerStats(totalCustomers: 0, newCustomers: 0, returningCustomers: 0),
    this.reservations = const ReservationStats(booked: 0, completed: 0, cancelled: 0, noShow: 0, noShowRate: 0),
  });

  final List<DailySales> daily;
  final List<MenuSales> menus;
  final CustomerStats customers;
  final ReservationStats reservations;

  final List<String> requests = []; // "daily:2026-11-01~2026-11-30" 처럼 종류와 기간
  Object? failWith; // 모든 호출이 이 에러로 실패

  /// 값이 있으면 일별 매출 응답이 이 Completer가 끝날 때까지 늦춰진다. (느린 서버와 요청 경쟁을 흉내 내려고)
  Completer<void>? gate;

  String _record(String kind, DateTime from, DateTime to) {
    final entry = '$kind:${formatIsoDate(from)}~${formatIsoDate(to)}';
    requests.add(entry);
    if (failWith != null) throw failWith!;
    return entry;
  }

  @override
  Future<List<DailySales>> dailySales(DateTime from, DateTime to) async {
    _record('daily', from, to);
    final waiting = gate; // 호출 시점의 gate를 잡아 둔다 (나중에 gate를 바꿔도 이 호출은 원래 gate를 기다린다)
    if (waiting != null) await waiting.future;
    return daily;
  }

  @override
  Future<List<MonthlySales>> monthlySales(int year) async => throw UnimplementedError();

  @override
  Future<List<MenuSales>> salesByMenu(DateTime from, DateTime to) async {
    _record('menus', from, to);
    return menus;
  }

  @override
  Future<CustomerStats> customerStats(DateTime from, DateTime to) async {
    _record('customers', from, to);
    return customers;
  }

  @override
  Future<ReservationStats> reservationStats(DateTime from, DateTime to) async {
    _record('reservations', from, to);
    return reservations;
  }
}
