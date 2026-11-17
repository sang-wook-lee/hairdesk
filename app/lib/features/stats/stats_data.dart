import '../sales/sale.dart';
import '../sales/sale_repository.dart';
import 'stats.dart';
import 'stats_calculations.dart';
import 'stats_month.dart';
import 'stats_repository.dart';

/// 통계 화면이 한 번에 쓰는 데이터 묶음. "한 달"치 통계 전부다.
///
/// 서버에서 받은 값과, 그 값에서 계산한 파생 값(건당 평균, 전월 대비, 결제수단 비중)을 함께 들고 있다.
/// 화면은 이 객체 하나만 받으면 되고, 계산식은 화면에 흩어지지 않고 stats_calculations.dart에만 있다.
class StatsData {
  const StatsData({
    required this.month,
    required this.comparisonRange,
    required this.comparisonLabel,
    required this.summary,
    required this.previousSummary,
    required this.daily,
    required this.menus,
    required this.customers,
    required this.reservations,
  });

  final StatsMonth month;

  /// 비교 대상 기간과 그 이름 ("지난달 같은 기간 대비" / "전월 대비"). 정하는 규칙은 StatsMonth.comparisonRange.
  final DateRange comparisonRange;
  final String comparisonLabel;

  final SalesSummary summary; // 이 달 총액, 건수, 결제수단별
  final SalesSummary previousSummary; // 비교 기간의 총액, 건수
  final List<DailySales> daily; // 이 달의 모든 날짜 (매출 없는 날은 0)
  final List<MenuSales> menus; // 메뉴별, 총액이 큰 순
  final CustomerStats customers;
  final ReservationStats reservations;

  /// 이 달에 결제가 한 건이라도 있는가. 없으면 화면이 "아직 매출이 없어요"를 보여준다.
  bool get hasSales => summary.count > 0;

  /// 건당 평균 매출. 건수가 0이면 null.
  int? get averageAmount => averagePerSale(summary.totalAmount, summary.count);

  /// 비교 기간 대비 매출 변화
  SalesChange get change => compareSales(summary.totalAmount, previousSummary.totalAmount);

  /// 결제수단별 비중 (금액이 큰 순, 합 100%)
  List<MethodShare> get methodShares => paymentMethodShares(summary.byMethod);
}

/// 한 달치 통계를 서버에서 한꺼번에 불러와 [StatsData]로 묶는다.
///
/// 호출 6개(요약, 비교 기간 요약, 일별, 메뉴별, 고객, 예약)를 동시에 보내서 한 번 기다린 시간으로 끝낸다.
/// "무엇을 어떤 기간으로 부를지"가 한 곳에만 있어서, 달 이동이나 비교 규칙이 바뀌어도 여기만 보면 된다.
class StatsLoader {
  // 비공개 필드(_stats)를 이름 있는 매개변수로 바로 받는다. 호출하는 쪽에서는 stats:, sales: 라는 이름으로 넘긴다. (Dart 3.12+)
  StatsLoader({required this._stats, required this._sales});

  final StatsRepository _stats;
  final SaleRepository _sales;

  /// [month]의 통계를 불러온다. [today]는 서울 기준 오늘이고, 비교 기간을 정하는 데 쓴다.
  /// 하나라도 실패하면 그 에러(ApiException 등)가 그대로 던져진다.
  Future<StatsData> load(StatsMonth month, {required DateTime today}) async {
    final range = month.range;
    final comparison = month.comparisonRange(today);

    // Future.wait는 실패 시 원래 에러를 그대로 던진다. (홈 화면에서 확인한 이유와 같다. 레코드의 .wait는 에러를 감싼다)
    // 결과는 넣은 순서대로 들어 있어서 번호로 꺼내 원래 타입으로 바꾼다.
    final results = await Future.wait<Object>([
      _sales.summarize(range.from, range.to),
      _sales.summarize(comparison.from, comparison.to),
      _stats.dailySales(range.from, range.to),
      _stats.salesByMenu(range.from, range.to),
      _stats.customerStats(range.from, range.to),
      _stats.reservationStats(range.from, range.to),
    ]);

    return StatsData(
      month: month,
      comparisonRange: comparison,
      comparisonLabel: month.comparisonLabel(today),
      summary: results[0] as SalesSummary,
      previousSummary: results[1] as SalesSummary,
      daily: results[2] as List<DailySales>,
      menus: results[3] as List<MenuSales>,
      customers: results[4] as CustomerStats,
      reservations: results[5] as ReservationStats,
    );
  }
}
