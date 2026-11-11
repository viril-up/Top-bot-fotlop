import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VirilApp());
}

const _bg = Color(0xFF0B0D15);
const _panel = Color(0xFF171B2A);
const _panel2 = Color(0xFF1E2335);
const _line = Color(0x2EA4B4DC);
const _blue = Color(0xFF8BDcff);
const _violet = Color(0xFFB5A0FF);
const _muted = Color(0xFF929BB4);
const _green = Color(0xFF8BE8BD);

class VirilApp extends StatelessWidget {
  const VirilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viril — Life RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _blue,
          secondary: _violet,
          surface: _panel,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const VirilSplash(),
    );
  }
}

class VirilSplash extends StatefulWidget {
  const VirilSplash({super.key});

  @override
  State<VirilSplash> createState() => _VirilSplashState();
}

class _VirilSplashState extends State<VirilSplash> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const VirilHome(),
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.65, -0.75),
            radius: 1.35,
            colors: [Color(0xFF182A45), _bg, _bg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(colors: [_blue, _violet]),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(.18), blurRadius: 35)],
                ),
                child: const Icon(Icons.psychology_alt_rounded, color: _bg, size: 42),
              ),
              const SizedBox(height: 18),
              const Text('VIRIL', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 5)),
              const SizedBox(height: 8),
              const Text('BECOME YOUR BEST VERSION', style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 2)),
              const SizedBox(height: 30),
              SizedBox(width: 92, child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goal {
  _Goal(this.title, {this.done = false, this.xp = 10});
  final String title;
  bool done;
  final int xp;

  Map<String, dynamic> toJson() => {'title': title, 'done': done, 'xp': xp};
  factory _Goal.fromJson(Map<String, dynamic> json) => _Goal(
    json['title']?.toString() ?? '',
    done: json['done'] == true,
    xp: (json['xp'] as num?)?.toInt() ?? 10,
  );
}

class VirilHome extends StatefulWidget {
  const VirilHome({super.key});

  @override
  State<VirilHome> createState() => _VirilHomeState();
}

class _VirilHomeState extends State<VirilHome> {
  int _tab = 0;
  int _xp = 0;
  int _focusSessions = 0;
  String _nickname = 'Viril';
  bool _loaded = false;
  final List<_Goal> _goals = [];
  final List<String> _diary = [];

  static const _tabs = [
    (Icons.grid_view_rounded, 'Главная'),
    (Icons.flag_rounded, 'Цели'),
    (Icons.fitness_center_rounded, 'Тренировки'),
    (Icons.menu_book_rounded, 'Книги'),
    (Icons.person_rounded, 'Профиль'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('viril_flutter_goals') ?? [];
    if (!mounted) return;
    setState(() {
      _xp = prefs.getInt('viril_flutter_xp') ?? 0;
      _focusSessions = prefs.getInt('viril_flutter_focus') ?? 0;
      _nickname = prefs.getString('viril_flutter_name') ?? 'Viril';
      _goals
        ..clear()
        ..addAll(saved.map((raw) {
          final parts = raw.split('|');
          return _Goal(parts.first, done: parts.length > 1 && parts[1] == '1');
        }));
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('viril_flutter_xp', _xp);
    await prefs.setInt('viril_flutter_focus', _focusSessions);
    await prefs.setString('viril_flutter_name', _nickname);
    await prefs.setStringList('viril_flutter_goals',
      _goals.map((g) => '${g.title.replaceAll('|', ' ')}|${g.done ? '1' : '0'}').toList());
  }

  int get _level {
    var level = 1;
    var remaining = _xp;
    while (level < 100) {
      final need = level == 1 ? 100 : 100 + (level - 1) * 50;
      if (remaining < need) break;
      remaining -= need;
      level++;
    }
    return level;
  }

  int get _levelStart => _level == 1 ? 0 : 100 + (_level - 2) * 50;
  int get _nextThreshold => _level == 1 ? 100 : 100 + (_level - 1) * 50;
  double get _progress => ((_xp - _levelStart) / (_nextThreshold - _levelStart)).clamp(0.0, 1.0);

  Future<void> _toggleGoal(_Goal goal) async {
    setState(() {
      goal.done = !goal.done;
      _xp = (_xp + (goal.done ? goal.xp : -goal.xp)).clamp(0, 999999);
    });
    await _save();
  }

  Future<void> _addGoal() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel2,
        title: const Text('Новая цель'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Например, прочитать 10 страниц'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Добавить')),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() => _goals.add(_Goal(value.trim())));
    await _save();
  }

  Future<void> _addFocus() async {
    setState(() { _focusSessions++; _xp += 5; });
    await _save();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('+5 XP · Фокус-сессия записана')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator(color: _blue)));
    final pages = [_dashboard(), _goalsPage(), _trainingPage(), _booksPage(), _profilePage()];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(-.9, -.95), radius: 1.5, colors: [Color(0xFF17243A), _bg, _bg]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    Expanded(child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
                    )),
                    const SizedBox(height: 10),
                    _navigation(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _tab = 4),
        child: Row(children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [Color(0xFF243D59), Color(0xFF42365E)]),
            border: Border.all(color: const Color(0xFF647BA5)),
          ), child: const Center(child: Text('🧠', style: TextStyle(fontSize: 22)))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_nickname, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text('Уровень $_level · ${_rank(_level)}', style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
        ]),
      ),
      const Spacer(),
      _pill(Icons.local_fire_department_rounded, '0 дней'),
      const SizedBox(width: 7),
      _iconButton(Icons.notifications_none_rounded, () => _toast('Уведомления появятся здесь')),
    ],
  );

  String _rank(int level) {
    if (level >= 25) return 'Легенда';
    if (level >= 15) return 'Мастер';
    if (level >= 10) return 'Элита';
    if (level >= 6) return 'Ветеран';
    if (level >= 3) return 'Воин';
    if (level >= 2) return 'Ученик';
    return 'Новичок';
  }

  Widget _dashboard() => ListView(
    key: const PageStorageKey('home'),
    children: [
      _levelCard(),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('ТВОЙ ДЕНЬ', style: TextStyle(fontSize: 11, color: _muted, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        Text('${_goals.where((g) => g.done).length}/${_goals.length} выполнено', style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 9),
      if (_goals.isEmpty) _empty('Пока нет целей на сегодня', 'Добавь первую цель и начни набирать XP'),
      ..._goals.take(4).map((g) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _goalTile(g),
      )),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _quickTile(Icons.flag_rounded, 'Цели', 'План на день', () => setState(() => _tab = 1))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.fitness_center_rounded, 'Тренировки', 'Сила и энергия', () => setState(() => _tab = 2))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.timer_rounded, 'Фокус', 'Сессия · +5 XP', _addFocus)),
      ]),
      const SizedBox(height: 12),
      _sectionCard(
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: _violet, size: 22),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Маленькие шаги. Большие перемены.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            SizedBox(height: 4),
            Text('Сосредоточься на прогрессе, а не на идеале.', style: TextStyle(color: _muted, fontSize: 11)),
          ])),
        ]),
      ),
    ],
  );

  Widget _levelCard() => _sectionCard(
    padding: const EdgeInsets.all(17),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('ТВОЙ ПРОГРЕСС', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: _muted, fontWeight: FontWeight.w700)),
        Text('$_xp XP', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
      const SizedBox(height: 5),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Уровень $_level', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.7)),
        const Spacer(),
        Text(_rank(_level), style: const TextStyle(color: _violet, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 13),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
        value: _progress, minHeight: 7, backgroundColor: const Color(0xFF30364B),
        valueColor: const AlwaysStoppedAnimation(_blue),
      )),
      const SizedBox(height: 7),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${_xp - _levelStart} XP', style: const TextStyle(color: _muted, fontSize: 10)),
        Text('Следующий уровень · $_nextThreshold XP', style: const TextStyle(color: _muted, fontSize: 10)),
      ]),
    ]),
  );

  Widget _goalsPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _pageHeading('Мои цели', 'Каждая выполненная цель приносит XP', action: _iconButton(Icons.add_rounded, _addGoal)),
    const SizedBox(height: 12),
    Expanded(child: _goals.isEmpty
      ? _empty('Список пока пуст', 'Нажми +, чтобы добавить первую цель')
      : ListView(children: _goals.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 9), child: _goalTile(g),
        )).toList())),
    const SizedBox(height: 8),
    _sectionCard(child: Row(children: [
      const Icon(Icons.info_outline_rounded, color: _blue),
      const SizedBox(width: 10),
      const Expanded(child: Text('Отмечай выполненные задачи, чтобы получать опыт и продвигаться по уровням.', style: TextStyle(color: _muted, fontSize: 11))),
    ])),
  ]);

  Widget _trainingPage() => ListView(children: [
    _pageHeading('Тренировки', 'Отмечай подходы и фиксируй прогресс'),
    const SizedBox(height: 12),
    _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('СЕГОДНЯ', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.3)),
      const SizedBox(height: 8),
      const Text('Твой прогресс начинается с одного подхода', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Это демонстрационный журнал тренировок. Записывай выполненные подходы.', style: TextStyle(color: _muted, fontSize: 11)),
    ])),
    const SizedBox(height: 10),
    _exercise('Отжимания', 'Собственный вес', Icons.fitness_center_rounded),
    _exercise('Подтягивания', 'Собственный вес', Icons.sports_gymnastics_rounded),
    _exercise('Приседания', 'Собственный вес', Icons.directions_run_rounded),
    _exercise('Планка', 'Время', Icons.timer_outlined),
  ]);

  Widget _exercise(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: _sectionCard(child: Row(children: [
      _iconSquare(icon, _blue),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w750, fontSize: 13)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
      ])),
      FilledButton.tonal(
        onPressed: () async { setState(() => _xp += 3); await _save(); if (mounted) _toast('+3 XP · Подход записан'); },
        child: const Text('+ Подход'),
      ),
    ])),
  );

  Widget _booksPage() => ListView(children: [
    _pageHeading('Библиотека', 'Материалы для развития'),
    const SizedBox(height: 12),
    _book('📘', 'Саморазвитие', 'Книги и материалы для личного роста'),
    _book('🧠', 'Психология', 'Понимание себя и своих привычек'),
    _book('🌍', 'Языки', 'Изучение и практика иностранных языков'),
    _book('🎯', 'Навыки', 'Концентрация, дисциплина и мышление'),
    const SizedBox(height: 8),
    _sectionCard(child: const Text('Каталог пока оформлен как предварительный интерфейс. Подключение исходной библиотеки книг — следующий этап переноса.', style: TextStyle(color: _muted, fontSize: 11))),
  ]);

  Widget _book(String emoji, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: _sectionCard(child: Row(children: [
      Container(width: 48, height: 58, decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w750, fontSize: 13)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: _muted),
    ])),
  );

  Widget _profilePage() => ListView(children: [
    _pageHeading('Профиль', 'Твоя личная зона Viril'),
    const SizedBox(height: 14),
    _sectionCard(child: Column(children: [
      Container(width: 76, height: 76, decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF243D59), Color(0xFF42365E)]),
        border: Border.all(color: _blue.withOpacity(.55)),
      ), child: const Center(child: Text('🧠', style: TextStyle(fontSize: 34)))),
      const SizedBox(height: 10),
      Text(_nickname, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
      const SizedBox(height: 3),
      Text('Уровень $_level · ${_rank(_level)}', style: const TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _editName, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Изменить имя')),
    ])),
    const SizedBox(height: 10),
    _profileOption(Icons.bolt_rounded, 'Опыт', '$_xp XP'),
    _profileOption(Icons.timer_outlined, 'Фокус-сессии', '$_focusSessions'),
    _profileOption(Icons.cloud_outlined, 'Синхронизация', 'Локальный режим предпросмотра'),
    _profileOption(Icons.settings_outlined, 'Настройки', 'Будут подключены при переносе модулей'),
  ]);

  Future<void> _editName() async {
    final controller = TextEditingController(text: _nickname);
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      backgroundColor: _panel2,
      title: const Text('Имя профиля'),
      content: TextField(controller: controller, maxLength: 24, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Сохранить')),
      ],
    ));
    if (value != null && value.trim().isNotEmpty) {
      setState(() => _nickname = value.trim().substring(0, value.trim().length.clamp(0, 24)));
      await _save();
    }
  }

  Widget _profileOption(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _sectionCard(child: Row(children: [
      Icon(icon, color: _blue, size: 19),
      const SizedBox(width: 11),
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w650, fontSize: 12))),
      Text(value, style: const TextStyle(color: _muted, fontSize: 10)),
    ])),
  );

  Widget _goalTile(_Goal goal) => InkWell(
    borderRadius: BorderRadius.circular(15),
    onTap: () => _toggleGoal(goal),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: const Color(0xCC1B2030), border: Border.all(color: _line), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Container(width: 23, height: 23, decoration: BoxDecoration(
          color: goal.done ? const Color(0xFF24493E) : const Color(0xFF151A29),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: goal.done ? _green : const Color(0xFF58627D)),
        ), child: goal.done ? const Icon(Icons.check_rounded, color: _green, size: 16) : null),
        const SizedBox(width: 10),
        Expanded(child: Text(goal.title, style: TextStyle(fontSize: 12, color: goal.done ? _muted : Colors.white, decoration: goal.done ? TextDecoration.lineThrough : null))),
        Text('+${goal.xp} XP', style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _quickTile(IconData icon, String title, String subtitle, VoidCallback action) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xCC20263A), Color(0xCC111522)]), border: Border.all(color: _line), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconSquare(icon, _blue, size: 30),
        const SizedBox(height: 8),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(height: 3),
        Text(subtitle, maxLines: 2, style: const TextStyle(color: _muted, fontSize: 9)),
      ]),
    ),
  );

  Widget _sectionCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xDD1A1F30), Color(0xCC111522)]),
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 8))],
    ),
    child: child,
  );

  Widget _empty(String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(border: Border.all(color: _line, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16), color: _panel.withOpacity(.55)),
    child: Column(children: [
      const Icon(Icons.auto_awesome_outlined, color: _muted, size: 25),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 4),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 10)),
    ]),
  );

  Widget _pageHeading(String title, String subtitle, {Widget? action}) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.5)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
    ])),
    if (action != null) action,
  ]);

  Widget _iconSquare(IconData icon, Color color, {double size = 34}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(11)),
    child: Icon(icon, color: color, size: size * .56),
  );

  Widget _pill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: _panel.withOpacity(.7), border: Border.all(color: _line), borderRadius: BorderRadius.circular(13)),
    child: Row(children: [Icon(icon, color: const Color(0xFFFFC875), size: 15), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]),
  );

  Widget _iconButton(IconData icon, VoidCallback action) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(13),
    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: _panel.withOpacity(.7), border: Border.all(color: _line), borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 19, color: _muted)),
  );

  Widget _navigation() => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xEE0E111C), border: Border.all(color: _line), borderRadius: BorderRadius.circular(19)),
    child: Row(children: List.generate(_tabs.length, (index) {
      final active = _tab == index;
      return Expanded(child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(color: active ? _blue.withOpacity(.1) : Colors.transparent, borderRadius: BorderRadius.circular(13)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_tabs[index].$1, size: 19, color: active ? _blue : _muted),
            const SizedBox(height: 3),
            Text(_tabs[index].$2, style: TextStyle(fontSize: 9, color: active ? _blue : _muted, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
          ]),
        ),
      ));
    })),
  );

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
