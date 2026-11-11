import 'package:flutter/material.dart';

import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';
import 'viril_training_screen.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  Future<void> _addFutureGoal() async {
    final text = TextEditingController();
    var period = 'week';
    var reward = 10;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Долгосрочная цель'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: text,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Название цели',
                hintText: 'Чему хочешь уделить внимание?',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: period,
              decoration: const InputDecoration(labelText: 'Период'),
              items: const [
                DropdownMenuItem(value: 'week', child: Text('Неделя')),
                DropdownMenuItem(value: 'month', child: Text('Месяц')),
                DropdownMenuItem(value: 'year', child: Text('Год')),
              ],
              onChanged: (value) => setModalState(() => period = value ?? 'week'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final value in [5, 10, 15])
                ChoiceChip(
                  label: Text('+$value XP'),
                  selected: reward == value,
                  onSelected: (_) => setModalState(() => reward = value),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (result == true && text.text.trim().isNotEmpty) {
      await widget.controller.addGoal(
        text: text.text,
        period: period,
        rewardXp: reward,
        penalty: 5,
      );
    }
    text.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final goals = widget.controller.state.futureGoals;
        return Scaffold(
          appBar: AppBar(title: const Text('Развитие', style: TextStyle(fontWeight: FontWeight.w800))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const Text('РАЗВИВАЙ СВОИ НАВЫКИ',
                style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.3)),
              const SizedBox(height: 7),
              const Text('Твой путь состоит из маленьких шагов.',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VirilTrainingScreen(controller: widget.controller),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D3551),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.fitness_center_rounded, color: VirilTheme.blue, size: 25),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_outward_rounded, color: Colors.white54),
                      ]),
                      const SizedBox(height: 14),
                      const Text('Viril Training', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('Каталог из 448 упражнений, планы тренировок и история подходов.',
                        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
                      const SizedBox(height: 12),
                      const Row(children: [
                        _SmallTag(label: '448 упражнений'),
                        SizedBox(width: 7),
                        _SmallTag(label: 'XP и статистика'),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('ЦЕЛИ НА ПЕРСПЕКТИВУ',
                  style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
                TextButton.icon(onPressed: _addFutureGoal,
                  icon: const Icon(Icons.add, size: 17), label: const Text('Добавить')),
              ]),
              if (goals.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(children: [
                      Icon(Icons.flag_outlined, color: VirilTheme.blue, size: 26),
                      SizedBox(height: 8),
                      Text('Долгосрочные планы', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Создай цель на неделю, месяц или год.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ]),
                  ),
                )
              else
                ...goals.map((goal) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.flag_rounded, color: VirilTheme.violet),
                    title: Text((goal['text'] ?? '').toString(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text((goal['period'] ?? 'week').toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    trailing: Text('+ ${goal['xp'] ?? 0} XP',
                      style: const TextStyle(color: VirilTheme.blue, fontSize: 11)),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: VirilTheme.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  );
}
