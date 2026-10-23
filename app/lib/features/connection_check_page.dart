import 'package:flutter/material.dart';

import '../core/api_client.dart';

/// 서버와 연결되는지 확인하는 임시 화면. 메뉴 목록 화면을 만들면 지운다.
///
/// StatefulWidget: 화면이 "상태"(불러오는 중 / 성공 / 실패)를 가지고, 상태가 바뀌면 다시 그려지는 위젯.
class ConnectionCheckPage extends StatefulWidget {
  const ConnectionCheckPage({super.key});

  @override
  State<ConnectionCheckPage> createState() => _ConnectionCheckPageState();
}

class _ConnectionCheckPageState extends State<ConnectionCheckPage> {
  final _api = ApiClient();

  /// 서버에서 불러올 데이터. Future = "아직 도착하지 않았지만 곧 올 값".
  late Future<List<dynamic>> _menus;

  @override
  void initState() {
    super.initState();
    _menus = _load(); // 화면이 처음 만들어질 때 한 번 불러온다.
  }

  Future<List<dynamic>> _load() async {
    final json = await _api.getJson('/api/menus');
    return json as List<dynamic>;
  }

  void _retry() {
    // setState: "상태가 바뀌었으니 화면을 다시 그려줘"라는 신호.
    setState(() {
      _menus = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('hairdesk 연결 확인')),
      // FutureBuilder: Future의 진행 상황(대기/완료/실패)에 맞춰 다른 화면을 보여준다.
      body: FutureBuilder<List<dynamic>>(
        future: _menus,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error!, onRetry: _retry);
          }
          final menus = snapshot.data!;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('서버에 연결되었습니다'),
                subtitle: Text('시술 메뉴 ${menus.length}개를 불러왔어요'),
              ),
              const Divider(),
              for (final menu in menus)
                ListTile(
                  title: Text(menu['name'] as String),
                  subtitle: Text('${menu['durationMinutes']}분'),
                  trailing: Text('${menu['price']}원'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 서버가 꺼져 있거나 CORS가 막히면 ApiException이 아니라 네트워크 예외가 온다.
    final message = error is ApiException
        ? (error as ApiException).message
        : '서버에 연결할 수 없습니다.\n서버가 켜져 있는지 확인해 주세요.\n($error)';
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
