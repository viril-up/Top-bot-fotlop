import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  String _mode = 'world';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _mine;
  int? _myRank;
  late bool _wasRegistered;
  late int _lastXp;

  String _league(int xp) => xp >= 10000 ? 'Легенда'
      : xp >= 5000 ? 'Алмаз'
      : xp >= 2500 ? 'Платина'
      : xp >= 1000 ? 'Золото'
      : xp >= 300 ? 'Серебро' : 'Бронза';

  ({int index, DateTime start, DateTime end, int remaining}) _season() {
    final now = DateTime.now().toUtc();
    final anchor = DateTime.utc(2026, 1, 1);
    final days = now.difference(anchor).inDays;
    final index = days ~/ 30;
    final start = anchor.add(Duration(days: index * 30));
    final end = start.add(const Duration(days: 30));
    return (
      index: index + 1,
      start: start,
      end: end,
      remaining: mathMax(0, end.difference(now).inDays + (end.difference(now).inHours % 24 == 0 ? 0 : 1)),
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;

  @override
  void initState() {
    super.initState();
    _wasRegistered = widget.controller.isRegistered;
    _lastXp = widget.controller.state.xp;
    widget.controller.addListener(_onControllerChanged);
    _load();
  }

  void _onControllerChanged() {
    final registered = widget.controller.isRegistered;
    final xp = widget.controller.state.xp;
    if (registered != _wasRegistered || xp != _lastXp) {
      _wasRegistered = registered;
      _lastXp = xp;
      _load();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.controller.isRegistered) {
      if (mounted) setState(() {
        _rows = [];
        _mine = null;
        _myRank = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = widget.controller.repository.client;
      final order = _mode == 'world' ? 'xp_total' : 'season_xp';
      final raw = await client
          .from('public_leaderboard')
          .select('user_id,nickname,avatar,xp_total,season_xp,level,season_best')
          .order(order, ascending: false)
          .limit(50);
      var rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final userId = widget.controller.repository.user?.id;
      Map<String, dynamic>? mine;
      int? rank;
      if (userId != null) {
        final own = await client
            .from('public_leaderboard')
            .select('user_id,nickname,avatar,xp_total,season_xp,level,season_best')
            .eq('user_id', userId)
            .maybeSingle();
        if (own != null) {
          mine = Map<String, dynamic>.from(own);
          final count = await client
              .from('profiles')
              .select('user_id')
              .gt('xp_total', mine['xp_total'])
              .count(CountOption.exact);
          rank = count.count + 1;
        }
      }
      if (_mode == 'me') rows = mine == null ? [] : [mine];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _mine = mine;
        _myRank = rank;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _displayDate(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  Widget _tab(String mode, String label) {
    final selected = _mode == mode;
    return Expanded(child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: () {
          setState(() => _mode = mode);
          _load();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? VirilTheme.blue.withValues(alpha: .16) : Colors.transparent,
          foregroundColor: selected ? VirilTheme.blue : Colors.white60,
          side: BorderSide(color: selected ? VirilTheme.blue : Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10)),
      ),
    ));
  }

  Widget _avatar(Map<String, dynamic> row) {
    final value = (row['avatar'] ?? '🧠').toString();
    if (value.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(value, width: 38, height: 38, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person)),
      );
    }
    return Container(
      width: 38, height: 38, alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF26344C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(value, style: const TextStyle(fontSize: 19)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final season = _season();
    final registered = widget.controller.isRegistered;
    final myXp = (_mine?['xp_total'] as num?)?.toInt() ?? 0;
    final mySeasonXp = (_mine?['season_xp'] as num?)?.toInt() ?? 0;
    final myName = (_mine?['nickname'] ?? 'Новичок').toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Глобальная лига'),
        actions: [
          IconButton(onPressed: _loading ? null : _load,
            tooltip: 'Обновить рейтинг', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.white12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF202943), Color(0xFF141A2B)],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VIRIL · WORLD LEAGUE',
                  style: TextStyle(color: VirilTheme.blue, fontSize: 10,
                    letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Сезон ' + season.index.toString(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  'До завершения сезона: ' + season.remaining.toString() +
                  ' дн. · ' + _displayDate(season.start) + ' — ' + _displayDate(season.end),
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _heroStat(_myRank == null ? '—' : '#' + _myRank.toString(), 'МОЁ МЕСТО'),
                  const SizedBox(width: 8),
                  _heroStat(mySeasonXp.toString(), 'XP СЕЗОНА'),
                  const SizedBox(width: 8),
                  _heroStat(registered ? _league(myXp) : 'Новичок', 'ЛИГА'),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _tab('world', 'Топ-50 мира'),
              _tab('records', 'Рекорды сезона'),
              _tab('me', 'Мой результат'),
            ]),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(
                      _mode == 'me' ? 'Мой результат'
                        : _mode == 'records' ? 'Рекорды текущего сезона'
                        : 'Лучшие игроки мира',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    )),
                    if (_loading)
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 8),
                  if (!registered)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Войди через Google, чтобы участвовать в мировой лиге и видеть свой результат.',
                        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Не удалось загрузить рейтинг: ' + _error!,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    )
                  else if (!_loading && _rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Пока нет игроков в рейтинге. Выполни задание после входа через Google.',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    )
                  else
                    for (var i = 0; i < _rows.length; i++)
                      _leaderRow(_rows[i], i),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('Рейтинг обновляется после подтверждённого выполнения задания. Для участия в мировой лиге войди через Google.',
                style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5)),
            ),
            if (_mine != null)
              Text('Твой профиль: ' + myName,
                style: const TextStyle(color: Colors.white30, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 8)),
    ]),
  ));

  Widget _leaderRow(Map<String, dynamic> row, int index) {
    final xp = (row['xp_total'] as num?)?.toInt() ?? 0;
    final seasonXp = (row['season_xp'] as num?)?.toInt() ?? 0;
    final best = (row['season_best'] as num?)?.toInt() ?? seasonXp;
    final level = (row['level'] as num?)?.toInt() ?? 1;
    final isMe = row['user_id'] == widget.controller.repository.user?.id;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(children: [
        SizedBox(width: 27, child: Text(
          _mode == 'me' ? '★' : (index + 1).toString(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isMe ? VirilTheme.blue : Colors.white54,
            fontWeight: FontWeight.w800, fontSize: 12,
          ),
        )),
        const SizedBox(width: 8),
        _avatar(row),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((row['nickname'] ?? 'Игрок Viril').toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              color: isMe ? VirilTheme.blue : Colors.white)),
          const SizedBox(height: 3),
          Text('Уровень ' + level.toString() + ' · ' + _league(xp),
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
        Text((_mode == 'records' ? best : seasonXp).toString() + ' XP',
          style: const TextStyle(color: VirilTheme.blue, fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
    );
  }
}
