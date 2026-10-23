import 'package:flutter/material.dart';

import '../../core/error_message.dart';
import '../../core/format.dart';
import '../../core/kst.dart';
import '../customer/customer_repository.dart';
import '../menu/menu_repository.dart';
import '../reservation/reservation.dart';
import '../reservation/reservation_form_page.dart';
import '../reservation/reservation_repository.dart';
import '../reservation/reservation_sheet.dart';
import '../reservation/reservation_tile.dart';
import '../sales/sale.dart';
import '../sales/sale_repository.dart';

/// 홈(메인) 화면. 앱을 열자마자 "오늘 무엇을 해야 하는지"가 보이게 한다.
///
/// 위에서 아래로 중요한 순서:
///   오늘 요약 → 매출 카드 → (처리 안 된 예약 알림) → 다음 예약 → 빠른 실행 → 오늘 일정
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.reservationRepository,
    required this.customerRepository,
    required this.menuRepository,
    required this.saleRepository,
    required this.onOpenSchedule,
    required this.onOpenMenus,
    this.clock = DateTime.now,
  });

  final ReservationRepository reservationRepository;
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;
  final SaleRepository saleRepository;

  /// 탭 이동은 화면 뼈대(HomeShell)의 일이라 콜백으로 부탁한다.
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMenus;

  /// "지금"을 알려주는 함수. 기본은 실제 시계이고, 테스트에서는 고정된 시각을 돌려주는 함수를 넣는다.
  /// (DateTime.now()를 화면 안에서 직접 부르면 "30분 뒤" 같은 글자를 테스트할 수 없다)
  final DateTime Function() clock;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 홈 화면이 한 번에 불러오는 데이터 묶음
class _HomeData {
  const _HomeData({
    required this.today,
    required this.reservations,
    required this.todaySales,
    required this.monthSales,
  });

  final DateTime today;
  final List<Reservation> reservations;
  final SalesSummary todaySales;
  final SalesSummary monthSales;
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _data = _load();

  Future<_HomeData> _load() async {
    final today = kstToday(now: widget.clock());
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0); // 0일 = 전달 마지막 날 → 이번 달 말일

    // 서로 상관없는 요청 3개를 동시에 보내고 모두 끝나길 기다린다. (하나씩 보내면 3배 느리다)
    // Future.wait는 하나라도 실패하면 "그 에러 그대로" 던져 준다. (Dart 3의 레코드 `(a, b).wait`는
    // 에러를 ParallelWaitError로 한 겹 감싸서 던지기 때문에, 서버 메시지를 꺼내 쓰기 불편해 쓰지 않았다.)
    // 결과는 넣은 순서대로 들어 있어서, 번호로 꺼내 원래 타입으로 바꿔 쓴다.
    final results = await Future.wait<Object>([
      widget.reservationRepository.fetchBetween(today, today),
      widget.saleRepository.summarize(today, today),
      widget.saleRepository.summarize(monthStart, monthEnd),
    ]);
    final reservations = results[0] as List<Reservation>;
    final todaySales = results[1] as SalesSummary;
    final monthSales = results[2] as SalesSummary;
    return _HomeData(
      today: today,
      reservations: reservations,
      todaySales: todaySales,
      monthSales: monthSales,
    );
  }

  Future<void> _reload() {
    setState(() {
      _data = _load();
    });
    return _data.then((_) {}, onError: (_) {}); // 당겨서 새로고침 표시를 끝내려고 기다린다. 에러는 화면이 보여준다.
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 예약 상세 시트를 열고, 동작이 성공했으면 홈을 새로고침한다. (일정 화면과 같은 흐름)
  Future<void> _openDetail(Reservation reservation) async {
    final message = await ReservationSheet.show(
      context,
      reservation: reservation,
      reservationRepository: widget.reservationRepository,
      saleRepository: widget.saleRepository,
      menuRepository: widget.menuRepository,
    );
    if (message == null) return;
    _reload();
    if (!mounted) return;
    _toast(message);
  }

  Future<void> _addReservation() async {
    final created = await Navigator.of(context).push<Reservation>(
      MaterialPageRoute(
        builder: (_) => ReservationFormPage(
          reservationRepository: widget.reservationRepository,
          customerRepository: widget.customerRepository,
          menuRepository: widget.menuRepository,
          initialDate: kstToday(now: widget.clock()),
        ),
      ),
    );
    if (created == null) return;
    _reload();
    if (!mounted) return;
    _toast('예약을 추가했어요');
  }

  /// 아직 만들지 않은 기능의 버튼. 눌러도 아무 일 없이 안내만 한다.
  void _comingSoon(String feature) => _toast('$feature 기능은 준비 중이에요');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('hairdesk'),
        actions: [
          IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: errorMessage(snapshot.error!), onRetry: _reload);
          }
          // 넓은 화면(웹, 태블릿)에서 내용이 끝없이 늘어지지 않게 폭을 제한하고 가운데에 둔다.
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RefreshIndicator(onRefresh: _reload, child: _buildContent(snapshot.data!)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(_HomeData data) {
    final now = widget.clock();
    final reservations = data.reservations;

    // 같은 "예약" 상태라도 이미 끝난 시간이면 "처리 안 된 예약"으로 따로 센다.
    final booked = reservations.where((r) => r.status == ReservationStatus.booked).toList();
    final upcoming = booked.where((r) => r.endAt.isAfter(now)).toList();
    final overdue = booked.where((r) => !r.endAt.isAfter(now)).toList();
    final completed = reservations.where((r) => r.status == ReservationStatus.completed).length;

    return ListView(
      // 내용이 짧아도 아래로 당겨 새로고침이 되도록
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          today: data.today,
          summary: reservations.isEmpty
              ? '오늘은 예약이 없어요'
              : '남은 예약 ${upcoming.length}건 · 완료 $completed건',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _SalesCard(label: '오늘 매출', summary: data.todaySales)),
            const SizedBox(width: 12),
            Expanded(child: _SalesCard(label: '이번 달 매출', summary: data.monthSales)),
          ],
        ),
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 12),
          _OverdueBanner(count: overdue.length, onTap: () => _openDetail(overdue.first)),
        ],
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          _NoNextCard(onAdd: _addReservation)
        else
          _NextCard(
            reservation: upcoming.first,
            countdown: formatCountdown(
              start: upcoming.first.startAt,
              end: upcoming.first.endAt,
              now: now,
            ),
            onTap: () => _openDetail(upcoming.first),
          ),
        const SizedBox(height: 20),
        _SectionTitle('빠른 실행'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true, // ListView 안에 넣으려면 내용 높이만큼만 차지하게 해야 한다
          physics: const NeverScrollableScrollPhysics(), // 스크롤은 바깥 ListView가 한다
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: [
            _ActionTile(icon: Icons.event_available, label: '예약 추가', onTap: _addReservation),
            _ActionTile(
              icon: Icons.point_of_sale,
              label: '매출 등록',
              soon: true,
              onTap: () => _comingSoon('매출 등록'),
            ),
            _ActionTile(
              icon: Icons.people_outline,
              label: '고객 관리',
              soon: true,
              onTap: () => _comingSoon('고객 관리'),
            ),
            _ActionTile(
              icon: Icons.bar_chart,
              label: '매출·통계',
              soon: true,
              onTap: () => _comingSoon('매출·통계'),
            ),
            _ActionTile(icon: Icons.content_cut, label: '시술 메뉴', onTap: widget.onOpenMenus),
            _ActionTile(
              icon: Icons.event_busy,
              label: '휴무일 설정',
              soon: true,
              onTap: () => _comingSoon('휴무일 설정'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _SectionTitle('오늘 일정')),
            TextButton(onPressed: widget.onOpenSchedule, child: const Text('전체 보기')),
          ],
        ),
        if (reservations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('오늘은 예약이 없어요.')),
          )
        else ...[
          for (final r in reservations.take(5))
            ReservationTile(reservation: r, onTap: () => _openDetail(r)),
          if (reservations.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: TextButton(
                  onPressed: widget.onOpenSchedule,
                  child: Text('외 ${reservations.length - 5}건 더 보기'),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.summary});

  final DateTime today;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatKoreanDate(today), style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(summary, style: text.bodyLarge),
      ],
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.label, required this.summary});

  final String label;
  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelLarge),
            const SizedBox(height: 8),
            // FittedBox: 금액이 길어지면 글자를 줄여서 카드 안에 맞춘다 (줄바꿈으로 깨지지 않게)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatWon(summary.totalAmount), style: text.titleLarge),
            ),
            const SizedBox(height: 2),
            Text('${summary.count}건', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// 시간이 지났는데 아직 "예약" 상태인 건이 있을 때 보여주는 알림. 결제나 노쇼 처리를 깜빡하면 매출이 빠지기 때문이다.
class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.notification_important_outlined, color: scheme.onTertiaryContainer),
        title: Text('처리하지 않은 지난 예약이 $count건 있어요'),
        subtitle: const Text('결제나 노쇼 처리를 해 주세요'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.reservation, required this.countdown, required this.onTap});

  final Reservation reservation;
  final String countdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias, // 물결(탭) 효과가 카드 모서리 밖으로 번지지 않게
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('다음 예약', style: text.labelLarge),
                  const Spacer(),
                  Text(countdown, style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${r.customerName} · ${r.menuName}', style: text.titleLarge),
              Text('${formatHm(r.startAt)} ~ ${formatHm(r.endAt)}'),
              if (r.memo != null) Text('메모: ${r.memo}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(onPressed: onTap, child: const Text('상세 · 결제')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoNextCard extends StatelessWidget {
  const _NoNextCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(child: Text('남은 예약이 없어요')),
            OutlinedButton(onPressed: onAdd, child: const Text('예약 추가')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// 빠른 실행 버튼 한 칸. [soon]이면 아직 없는 기능이라 "준비 중" 표시를 붙이고 흐리게 보여준다.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.soon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = soon ? scheme.onSurfaceVariant.withValues(alpha: 0.6) : scheme.onSurface;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: soon ? color : scheme.primary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color)),
            if (soon) Text('준비 중', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
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
