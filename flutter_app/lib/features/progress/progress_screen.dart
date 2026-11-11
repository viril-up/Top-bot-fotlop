import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 14;
  String _metric = 'xp';
  int _selected = -1;

  String _dateKey(DateTime date) =>
      date.year.toString().padLeft(4, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' +
      date.day.toString().padLeft(2, '0');

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  List<_DayValue> _days() {
    final state = widget.controller.state;
    final now = DateTime.now();
    return List.generate(_range, (index) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _range - index - 1));
      final key = _dateKey(date);
      final history = _map(state.history[key]);
      final workout = _map(state.workouts[key]);
      final sets = (workout['sets'] as List? ?? const []).length;
      var goals = 0;
      var xp = 0;
      if (key == _dateKey(now)) {
        final completed = state.goals.where((goal) => goal['done'] == true);
        goals = completed.length;
        xp = completed.fold<int>(0, (sum, goal) => sum + _number(goal['xp']));
      } else {
        goals = _number(history['done']);
        xp = _number(history['earned']);
      }
      xp += _number(workout['xp']);
      return _DayValue(date, key, _metric == 'xp' ? xp : _metric == 'goals' ? goals : sets);
    });
  }

  Widget _stat(String value, String label) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = _dateKey(yesterday);
      final snapshot = _map(state.history[yesterdayKey]);
      final previousGoals = (snapshot['goals'] as List? ?? const [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final historyValues = state.history.values.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
      final allDone = historyValues.fold<int>(0, (sum, item) => sum + _number(item['done']));
      final allXp = historyValues.fold<int>(0, (sum, item) => sum + _number(item['earned']));
      final days = _days();
      final values = days.map((day) => day.value.toDouble()).toList();
      final total = values.fold<double>(0, (sum, value) => sum + value);
      final average = values.isEmpty ? 0.0 : total / values.length;
      final best = values.isEmpty ? 0.0 : values.reduce((a, b) => math.max(a, b).toDouble());
      final selectedIndex = _selected < 0 || _selected >= days.length ? days.length - 1 : _selected;
      final selectedDay = days.isEmpty ? null : days[selectedIndex];
      final unit = _metric == 'xp' ? 'XP' : _metric == 'goals' ? 'целей' : 'подходов';

      return Scaffold(
        appBar: AppBar(title: const Text('Аналитика')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Row(children: [
              _stat(_number(snapshot['done']).toString(), 'ВЫПОЛНЕНО ВЧЕРА'),
              _stat(_number(snapshot['net']).toString() + ' XP', 'ОПЫТ ЗА ВЧЕРА'),
            ]),
            Row(children: [
              _stat(_number(snapshot['score']).toString() + '/100', 'ОЦЕНКА ДНЯ'),
              _stat(state.level.toString(), 'ТЕКУЩИЙ УРОВЕНЬ'),
            ]),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Динамика прогресса',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                    _choiceGroup<int>(
                      value: _range,
                      values: const [7, 14, 30],
                      labels: const ['7д', '14д', '30д'],
                      onChanged: (value) => setState(() { _range = value; _selected = -1; }),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _choiceGroup<String>(
                    value: _metric,
                    values: const ['xp', 'goals', 'sets'],
                    labels: const ['XP', 'Цели', 'Подходы'],
                    onChanged: (value) => setState(() { _metric = value; _selected = -1; }),
                  ),
                  const SizedBox(height: 12),
                  if (selectedDay != null)
                    Text(
                      selectedDay.date.day.toString().padLeft(2, '0') + '.' +
                      selectedDay.date.month.toString().padLeft(2, '0') + ' · ' +
                      selectedDay.value.toString() + ' ' + unit,
                      style: const TextStyle(color: VirilTheme.blue, fontSize: 12,
                        fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final width = context.size?.width ?? 1;
                        final local = details.localPosition.dx.clamp(0.0, width);
                        final next = ((local / width) * (days.length - 1)).round();
                        setState(() => _selected = next);
                      },
                      child: CustomPaint(
                        painter: _ProgressChartPainter(
                          values: values,
                          dates: days.map((e) => e.date).toList(),
                          selected: selectedIndex,
                        ),
                      ),
                    ),
                  ),
                  Row(children: [
                    _summary(total.toStringAsFixed(0), 'ВСЕГО'),
                    _summary(average.toStringAsFixed(1), 'В СРЕДНЕМ / ДЕНЬ'),
                    _summary(best.toStringAsFixed(0), 'ЛУЧШИЙ ДЕНЬ'),
                  ]),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Вчерашние задания',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (previousGoals.isEmpty)
                    const Text('Пока нет данных за предыдущий день. Данные появятся после завершения первого дня с целями.',
                      style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5))
                  else
                    for (final goal in previousGoals)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Expanded(child: Text(
                            (goal['done'] == true ? '✓ ' : '○ ') + (goal['text'] ?? '').toString(),
                            style: TextStyle(
                              color: goal['done'] == true ? VirilTheme.green : Colors.white70,
                              fontSize: 12,
                            ),
                          )),
                          Text(
                            goal['done'] == true
                              ? '+' + _number(goal['xp']).toString() + ' XP'
                              : 'не выполнено',
                            style: TextStyle(
                              color: goal['done'] == true ? VirilTheme.green : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ]),
                      ),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Общий прогресс',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Всего выполнено целей: ' + allDone.toString() +
                    '. Заработано XP по истории: ' + allXp.toString() +
                    '. Дней в истории: ' + historyValues.length.toString() + '.',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _choiceGroup<T>({
    required T value,
    required List<T> values,
    required List<String> labels,
    required ValueChanged<T> onChanged,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: VirilTheme.background,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < values.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(values[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: value == values[i] ? VirilTheme.blue.withValues(alpha: .18) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(labels[i], style: TextStyle(
              color: value == values[i] ? VirilTheme.blue : Colors.white60,
              fontSize: 10, fontWeight: FontWeight.w700,
            )),
          ),
        ),
    ]),
  );

  Widget _summary(String value, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 8)),
      ]),
    ),
  );
}

class _DayValue {
  const _DayValue(this.date, this.key, this.value);
  final DateTime date;
  final String key;
  final int value;
}

class _ProgressChartPainter extends CustomPainter {
  const _ProgressChartPainter({
    required this.values,
    required this.dates,
    required this.selected,
  });

  final List<double> values;
  final List<DateTime> dates;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 30.0, right = 10.0, top = 12.0, bottom = 27.0;
    final chartWidth = math.max(1.0, size.width - left - right).toDouble();
    final chartHeight = math.max(1.0, size.height - top - bottom).toDouble();
    final maximum = math.max(4.0, values.reduce((a, b) => math.max(a, b).toDouble()) * 1.15).toDouble();
    Offset point(int index) => Offset(
      left + chartWidth * (values.length <= 1 ? 0 : index / (values.length - 1)),
      top + chartHeight * (1 - values[index] / maximum),
    );

    final gridPaint = Paint()..color = Colors.white.withValues(alpha: .09)..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white54, fontSize: 9);
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(text: (maximum * (4 - i) / 4).round().toString(), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - 5));
    }

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    final area = Path.from(line)
      ..lineTo(point(values.length - 1).dx, top + chartHeight)
      ..lineTo(point(0).dx, top + chartHeight)
      ..close();
    canvas.drawPath(area, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x558BDcff), Color(0x00B5A0FF)],
      ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight)));
    canvas.drawPath(line, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [VirilTheme.blue, VirilTheme.violet],
      ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight)));

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, i == selected ? 5 : 2.5,
        Paint()..color = i == selected ? Colors.white : VirilTheme.blue);
    }
    final chosen = selected.clamp(0, values.length - 1);
    final chosenPoint = point(chosen);
    canvas.drawLine(chosenPoint, Offset(chosenPoint.dx, top + chartHeight),
      Paint()..color = VirilTheme.blue.withValues(alpha: .4)..strokeWidth = 1);
    final step = (values.length / 7).ceil();
    for (var i = 0; i < dates.length; i++) {
      if ((values.length - 1 - i) % step != 0) continue;
      final d = dates[i];
      final label = TextPainter(
        text: TextSpan(
          text: d.day.toString() + '.' + d.month.toString().padLeft(2, '0'),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(
        (point(i).dx - label.width / 2).clamp(0.0, size.width - label.width).toDouble(),
        size.height - 16,
      ));
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.dates != dates ||
      oldDelegate.selected != selected;
}
