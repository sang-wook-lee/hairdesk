import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/kst.dart';
import 'stats_data.dart';
import 'stats_month.dart';
import 'widgets/counts_cards.dart';
import 'widgets/daily_sales_chart.dart';
import 'widgets/menu_ranking.dart';
import 'widgets/month_switcher.dart';
import 'widgets/payment_method_bar.dart';
import 'widgets/section_card.dart';
import 'widgets/summary_card.dart';

/// 매출·통계 화면. 한 달씩 넘겨 보며 요약, 일별 매출, 결제수단, 메뉴, 고객, 예약 현황을 본다.
///
/// 이 화면이 직접 하는 일은 두 가지뿐이다.
///  1) "지금 보는 달"(StatsMonth) 하나를 상태로 들고 있다.
///  2) 그 달의 데이터를 StatsLoader로 불러와서, 아래 층에서 만든 부품들을 순서대로 쌓는다.
/// 계산(전월 대비, 비율 등)은 StatsData, 그림은 widgets/ 가 맡는다.
class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.loader,
    this.refresh,
    this.clock = DateTime.now,
  });

  final StatsLoader loader;

  /// 이 신호가 울리면 보던 달 그대로 다시 불러온다. 다른 탭에서 결제하고 돌아왔을 때 숫자를 새로 고치려고
  /// 화면 뼈대(HomeShell)가 건네준다. 필요 없으면 생략한다.
  /// Listenable: "무언가 바뀌었다"는 소식을 받아 보는 구독 대상 (ChangeNotifier, ValueNotifier 등이 이것이다)
  final Listenable? refresh;

  /// "지금"을 알려주는 함수. 기본은 실제 시계이고, 테스트에서는 고정된 시각을 돌려주는 함수를 넣는다.
  final DateTime Function() clock;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime get _today => kstToday(now: widget.clock());

  late StatsMonth _month = StatsMonth.containing(_today); // 처음엔 이번 달
  late Future<StatsData> _data = _load();

  Future<StatsData> _load() => widget.loader.load(_month, today: _today);

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_reload);
  }

  @override
  void didUpdateWidget(StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모가 다른 신호를 건네줬다면 구독 대상을 바꾼다.
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_reload);
      widget.refresh?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_reload); // 구독을 풀지 않으면 화면이 사라진 뒤에도 신호가 와서 에러가 난다
    super.dispose();
  }

  /// 보던 달 그대로 다시 불러온다.
  void _reload() {
    if (!mounted) return;
    setState(() {
      _data = _load();
    });
  }

  /// 당겨서 새로고침. 로딩이 끝날 때까지 기다려야 새로고침 표시가 사라진다. (에러는 화면이 이미 보여주므로 여기선 삼킨다)
  Future<void> _refresh() {
    _reload();
    return _data.then((_) {}, onError: (_) {});
  }

  void _moveTo(StatsMonth month) {
    setState(() {
      _month = month;
      _data = _load(); // 새 달의 Future로 바꾸면 FutureBuilder가 로딩 → 결과 순으로 다시 그린다
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return Scaffold(
      appBar: AppBar(
        title: const Text('매출·통계'),
        actions: [IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      // 넓은 화면(웹, 태블릿)에서 내용이 끝없이 늘어지지 않게 폭을 제한하고 가운데에 둔다.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // 달 이동 줄은 목록 바깥에 둬서, 로딩 중이나 에러일 때도 달을 계속 바꿀 수 있다.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: MonthSwitcher(
                  month: _month,
                  canGoNext: _month.canGoNext(today),
                  isCurrent: _month.isCurrent(today),
                  onPrevious: () => _moveTo(_month.previous),
                  onNext: () => _moveTo(_month.next),
                  onToday: () => _moveTo(StatsMonth.containing(today)),
                ),
              ),
              Expanded(
                child: FutureBuilder<StatsData>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorView(message: errorMessage(snapshot.error!), onRetry: _reload);
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: _StatsBody(data: snapshot.data!, today: today),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 한 달치 통계를 구역별로 쌓은 목록. 위에서 아래로 중요한 순서다.
class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.data, required this.today});

  final StatsData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // 내용이 짧아도(매출 없는 달) 아래로 당겨 새로고침이 되도록
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        StatsSummaryCard(data: data),
        const SizedBox(height: 12),
        SectionCard(title: '일별 매출', child: DailySalesChart(days: data.daily, today: today)),
        const SizedBox(height: 12),
        SectionCard(title: '결제수단', child: PaymentMethodBar(shares: data.methodShares)),
        const SizedBox(height: 12),
        SectionCard(title: '메뉴별 매출', child: MenuRanking(menus: data.menus)),
        const SizedBox(height: 12),
        SectionCard(title: '고객', child: CustomerStatsBody(stats: data.customers)),
        const SizedBox(height: 12),
        SectionCard(title: '예약', child: ReservationStatsBody(stats: data.reservations)),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
