import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/viril_state.dart';
import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, this.onNavigate});
  final VirilController controller;
  final ValueChanged<int>? onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _addGoal() async {
    final text = TextEditingController();
    var period = 'day';
    var reward = 10;
    var penalty = 5;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Новая цель'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: text,
                maxLength: 120,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Например: 20 минут чтения',
                  labelText: 'Название цели',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Период'),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('На сегодня')),
                  DropdownMenuItem(value: 'week', child: Text('На неделю')),
                  DropdownMenuItem(value: 'month', child: Text('На месяц')),
                  DropdownMenuItem(value: 'year', child: Text('На год')),
                ],
                onChanged: (value) => setModalState(() => period = value ?? 'day'),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Награда')),
              Wrap(spacing: 8, children: [
                for (final value in [5, 10, 15])
                  ChoiceChip(
                    label: Text('+$value XP'),
                    selected: reward == value,
                    onSelected: (_) => setModalState(() => reward = value),
                  ),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: penalty,
                decoration: const InputDecoration(labelText: 'Штраф за невыполнение'),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('−5 XP')),
                  DropdownMenuItem(value: 10, child: Text('−10 XP')),
                ],
                onChanged: (value) => setModalState(() => penalty = value ?? 5),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Добавить')),
          ],
        ),
      ),
    );
    if (result == true && text.text.trim().isNotEmpty) {
      await widget.controller.addGoal(
        text: text.text,
        period: period,
        rewardXp: reward,
        penalty: penalty,
      );
    }
    text.dispose();
  }

  Future<void> _addDiaryEntry() async {
    final text = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дневник мыслей'),
        content: TextField(
          controller: text,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Что сегодня у тебя на уме?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == true) await widget.controller.addDiaryEntry(text.text);
    text.dispose();
  }

  void _openFocus() {
    showDialog<void>(
      context: context,
      builder: (_) => _FocusDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final goals = state.goals;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Row(children: [
                  const Text('VIRIL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: VirilTheme.panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('УРОВЕНЬ ${state.level}', style: const TextStyle(fontSize: 10, color: VirilTheme.blue)),
                  ),
                ]),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Chip(
                      avatar: const Icon(Icons.local_fire_department, color: Color(0xFFFFC875), size: 18),
                      label: Text('${state.currentStreak()} дней'),
                      side: BorderSide(color: Colors.white.withValues(alpha: .1)),
                      backgroundColor: VirilTheme.panel,
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.list(children: [
                  const Text('ТВОЙ СЛЕДУЮЩИЙ УРОВЕНЬ НАЧИНАЕТСЯ СЕГОДНЯ',
                    style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text('Маленькие действия. Большие изменения.',
                    style: TextStyle(fontSize: 23, height: 1.15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  _LevelCard(state: state),
                  const SizedBox(height: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('ПЛАНЫ НА СЕГОДНЯ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                    TextButton.icon(onPressed: _addGoal, icon: const Icon(Icons.add, size: 17), label: const Text('Добавить')),
                  ]),
                  if (goals.isEmpty)
                    const _EmptyGoals()
                  else
                    ...goals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: CheckboxListTile(
                          value: goal['done'] == true,
                          onChanged: (_) => widget.controller.toggleGoal(goal['id'].toString()),
                          title: Text(goal['text']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              decoration: goal['done'] == true ? TextDecoration.lineThrough : null,
                              color: goal['done'] == true ? Colors.white54 : Colors.white,
                            )),
                          secondary: Text('${goal['done'] == true ? '+' : ''}${goal['xp'] ?? 0} XP',
                            style: const TextStyle(color: VirilTheme.blue, fontSize: 11, fontWeight: FontWeight.w700)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    )),
                  const SizedBox(height: 12),
                  const Text('ИНСТРУМЕНТЫ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _MiniFeature(icon: Icons.menu_book_rounded, title: 'Дневник мыслей', caption: 'Записывай идеи', onTap: _addDiaryEntry),
                      _MiniFeature(icon: Icons.timer_outlined, title: 'Фокус', caption: 'Работа и отдых', onTap: _openFocus),
                      _MiniFeature(icon: Icons.bar_chart_rounded, title: 'Аналитика', caption: 'Изучай прогресс', onTap: () => widget.onNavigate?.call(3)),
                      _MiniFeature(icon: Icons.fitness_center_rounded, title: 'Тренировки', caption: 'Открой каталог', onTap: () => widget.onNavigate?.call(2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!widget.controller.cloudAvailable)
                    const Text('Локальное сохранение активно. Облачная синхронизация подключится при восстановлении связи.',
                      style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});
  final VirilState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ТВОЙ ПРОГРЕСС', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3)),
          Icon(Icons.auto_awesome, color: VirilTheme.blue),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${state.level}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(width: 9),
          Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Text(VirilState.rankFor(state.level), style: const TextStyle(color: VirilTheme.blue))),
          const Spacer(),
          Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Text('${state.xpIntoLevel} / ${VirilState.threshold(state.level + 1) - VirilState.threshold(state.level)} XP',
              style: const TextStyle(color: Colors.white60, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: state.levelProgress,
            minHeight: 7,
            backgroundColor: const Color(0xFF30364B),
            color: VirilTheme.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text('${state.xp} XP · ещё ${state.xpForNextLevel} XP до следующего уровня',
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ),
  );
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: VirilTheme.panel.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: const Column(children: [
      Icon(Icons.flag_outlined, color: VirilTheme.blue, size: 25),
      SizedBox(height: 8),
      Text('Твои планы появятся здесь', style: TextStyle(fontWeight: FontWeight.w700)),
      SizedBox(height: 3),
      Text('Нажми «Добавить», чтобы создать первую цель.',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
    ]),
  );
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.title, required this.caption, this.onTap});
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: VirilTheme.violet, size: 22),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 3),
          Text(caption, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    ),
  );
}

class _FocusDialog extends StatefulWidget {
  const _FocusDialog({required this.controller});
  final VirilController controller;
  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  Timer? timer;
  int seconds = 25 * 60;
  bool isRest = false;
  bool running = false;

  void choose(bool rest) {
    timer?.cancel();
    setState(() {
      isRest = rest;
      running = false;
      seconds = (rest ? 5 : 25) * 60;
    });
  }

  void startPause() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (tick) {
      if (seconds <= 1) {
        tick.cancel();
        if (!isRest) {
          widget.controller.recordFocusSession();
          setState(() {
            seconds = 5 * 60;
            isRest = true;
            running = false;
          });
        } else {
          setState(() {
            seconds = 25 * 60;
            isRest = false;
            running = false;
          });
        }
      } else {
        setState(() => seconds--);
      }
    });
  }

  void reset() {
    timer?.cancel();
    setState(() {
      running = false;
      seconds = (isRest ? 5 : 25) * 60;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: const Text('Фокус-режим'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isRest ? 'ОТДЫХ' : 'РАБОТА',
          style: const TextStyle(color: VirilTheme.blue, letterSpacing: 2, fontSize: 11)),
        const SizedBox(height: 12),
        Text(mm + ':' + ss,
          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
        const SizedBox(height: 15),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Работа 25 мин'),
            selected: !isRest, onSelected: (_) => choose(false)),
          ChoiceChip(label: const Text('Отдых 5 мин'),
            selected: isRest, onSelected: (_) => choose(true)),
        ]),
        const SizedBox(height: 10),
        Text('Завершено фокус-сессий: ' +
          (widget.controller.state.data['focusSessions'] ?? 0).toString(),
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
      actions: [
        TextButton(onPressed: reset, child: const Text('Сброс')),
        FilledButton(onPressed: startPause,
          child: Text(running ? 'Пауза' : 'Старт')),
      ],
    );
  }
}mport 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/viril_state.dart';
import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, this.onNavigate});
  final VirilController controller;
  final ValueChanged<int>? onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _addGoal() async {
    final text = TextEditingController();
    var period = 'day';
    var reward = 10;
    var penalty = 5;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Новая цель'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: text,
                maxLength: 120,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Например: 20 минут чтения',
                  labelText: 'Название цели',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Период'),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('На сегодня')),
                  DropdownMenuItem(value: 'week', child: Text('На неделю')),
                  DropdownMenuItem(value: 'month', child: Text('На месяц')),
                  DropdownMenuItem(value: 'year', child: Text('На год')),
                ],
                onChanged: (value) => setModalState(() => period = value ?? 'day'),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Награда')),
              Wrap(spacing: 8, children: [
                for (final value in [5, 10, 15])
                  ChoiceChip(
                    label: Text('+$value XP'),
                    selected: reward == value,
                    onSelected: (_) => setModalState(() => reward = value),
                  ),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: penalty,
                decoration: const InputDecoration(labelText: 'Штраф за невыполнение'),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('−5 XP')),
                  DropdownMenuItem(value: 10, child: Text('−10 XP')),
                ],
                onChanged: (value) => setModalState(() => penalty = value ?? 5),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Добавить')),
          ],
        ),
      ),
    );
    if (result == true && text.text.trim().isNotEmpty) {
      await widget.controller.addGoal(
        text: text.text,
        period: period,
        rewardXp: reward,
        penalty: penalty,
      );
    }
    text.dispose();
  }

  Future<void> _addDiaryEntry() async {
    final text = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дневник мыслей'),
        content: TextField(
          controller: text,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Что сегодня у тебя на уме?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == true) await widget.controller.addDiaryEntry(text.text);
    text.dispose();
  }

  void _openFocus() {
    showDialog<void>(
      context: context,
      builder: (_) => _FocusDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final goals = state.goals;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Row(children: [
                  const Text('VIRIL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: VirilTheme.panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('УРОВЕНЬ ${state.level}', style: const TextStyle(fontSize: 10, color: VirilTheme.blue)),
                  ),
                ]),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Chip(
                      avatar: const Icon(Icons.local_fire_department, color: Color(0xFFFFC875), size: 18),
                      label: Text('${state.currentStreak()} дней'),
                      side: BorderSide(color: Colors.white.withValues(alpha: .1)),
                      backgroundColor: VirilTheme.panel,
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.list(children: [
                  const Text('ТВОЙ СЛЕДУЮЩИЙ УРОВЕНЬ НАЧИНАЕТСЯ СЕГОДНЯ',
                    style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text('Маленькие действия. Большие изменения.',
                    style: TextStyle(fontSize: 23, height: 1.15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  _LevelCard(state: state),
                  const SizedBox(height: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('ПЛАНЫ НА СЕГОДНЯ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                    TextButton.icon(onPressed: _addGoal, icon: const Icon(Icons.add, size: 17), label: const Text('Добавить')),
                  ]),
                  if (goals.isEmpty)
                    const _EmptyGoals()
                  else
                    ...goals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: CheckboxListTile(
                          value: goal['done'] == true,
                          onChanged: (_) => widget.controller.toggleGoal(goal['id'].toString()),
                          title: Text(goal['text']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              decoration: goal['done'] == true ? TextDecoration.lineThrough : null,
                              color: goal['done'] == true ? Colors.white54 : Colors.white,
                            )),
                          secondary: Text('${goal['done'] == true ? '+' : ''}${goal['xp'] ?? 0} XP',
                            style: const TextStyle(color: VirilTheme.blue, fontSize: 11, fontWeight: FontWeight.w700)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    )),
                  const SizedBox(height: 12),
                  const Text('ИНСТРУМЕНТЫ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _MiniFeature(icon: Icons.menu_book_rounded, title: 'Дневник мыслей', caption: 'Записывай идеи', onTap: _addDiaryEntry),
                      _MiniFeature(icon: Icons.timer_outlined, title: 'Фокус', caption: 'Работа и отдых', onTap: _openFocus),
                      _MiniFeature(icon: Icons.bar_chart_rounded, title: 'Аналитика', caption: 'Изучай прогресс', onTap: () => widget.onNavigate?.call(3)),
                      _MiniFeature(icon: Icons.fitness_center_rounded, title: 'Тренировки', caption: 'Открой каталог', onTap: () => widget.onNavigate?.call(2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!widget.controller.cloudAvailable)
                    const Text('Локальное сохранение активно. Облачная синхронизация подключится при восстановлении связи.',
                      style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});
  final VirilState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ТВОЙ ПРОГРЕСС', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3)),
          Icon(Icons.auto_awesome, color: VirilTheme.blue),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${state.level}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(width: 9),
          Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Text(VirilState.rankFor(state.level), style: const TextStyle(color: VirilTheme.blue))),
          const Spacer(),
          Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Text('${state.xpIntoLevel} / ${VirilState.threshold(state.level + 1) - VirilState.threshold(state.level)} XP',
              style: const TextStyle(color: Colors.white60, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: state.levelProgress,
            minHeight: 7,
            backgroundColor: const Color(0xFF30364B),
            color: VirilTheme.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text('${state.xp} XP · ещё ${state.xpForNextLevel} XP до следующего уровня',
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ),
  );
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: VirilTheme.panel.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: const Column(children: [
      Icon(Icons.flag_outlined, color: VirilTheme.blue, size: 25),
      SizedBox(height: 8),
      Text('Твои планы появятся здесь', style: TextStyle(fontWeight: FontWeight.w700)),
      SizedBox(height: 3),
      Text('Нажми «Добавить», чтобы создать первую цель.',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
    ]),
  );
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.title, required this.caption, this.onTap});
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: VirilTheme.violet, size: 22),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 3),
          Text(caption, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    ),
  );
}

class _FocusDialog extends StatefulWidget {
  const _FocusDialog({required this.controller});
  final VirilController controller;
  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  Timer? timer;
  int seconds = 25 * 60;
  bool isRest = false;
  bool running = false;

  void choose(bool rest) {
    timer?.cancel();
    setState(() {
      isRest = rest;
      running = false;
      seconds = (rest ? 5 : 25) * 60;
    });
  }

  void startPause() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (tick) {
      if (seconds <= 1) {
        tick.cancel();
        setState(() { seconds = 0; running = false; });
        if (!isRest) widget.controller.recordFocusSession();
      } else {
        setState(() => seconds--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: const Text('Фокус-режим'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isRest ? 'ОТДЫХ' : 'РАБОТА', style: const TextStyle(color: VirilTheme.blue, letterSpacing: 2, fontSize: 11)),
        const SizedBox(height: 12),
        Text('$mm:$ss', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, fontFeatures: [])),
        const SizedBox(height: 15),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Работа 25 мин'), selected: !isRest, onSelected: (_) => choose(false)),
          ChoiceChip(label: const Text('Отдых 5 мин'), selected: isRest, onSelected: (_) => choose(true)),
        ]),
        const SizedBox(height: 10),
        Text('Завершено фокус-сессий: ${widget.controller.state.data['focusSessions'] ?? 0}',
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
      actions: [
        TextButton(onPressed: () => choose(isRest), child: const Text('Сброс')),
        FilledButton(onPressed: startPause, child: Text(running ? 'Пауза' : 'Старт')),
      ],
    );
  }
}
