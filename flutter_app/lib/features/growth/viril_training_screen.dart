import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/viril_controller.dart';
import 'exercise_art.dart';
import '../../core/theme/viril_theme.dart';

class TrainingExercise {
  const TrainingExercise({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.equipment,
    required this.difficulty,
    required this.art,
    required this.steps,
    required this.aliases,
  });

  final String id;
  final String name;
  final String primary;
  final List<String> secondary;
  final String equipment;
  final String difficulty;
  final String art;
  final List<String> steps;
  final List<String> aliases;

  factory TrainingExercise.fromJson(Map<String, dynamic> json) {
    return TrainingExercise(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      primary: (json['primary'] ?? '').toString(),
      secondary: (json['secondary'] as List? ?? const []).map((e) => e.toString()).toList(),
      equipment: (json['equipment'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      art: (json['art'] ?? '').toString(),
      steps: (json['steps'] as List? ?? const []).map((e) => e.toString()).toList(),
      aliases: (json['aliases'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class VirilTrainingScreen extends StatefulWidget {
  const VirilTrainingScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<VirilTrainingScreen> createState() => _VirilTrainingScreenState();
}

class _VirilTrainingScreenState extends State<VirilTrainingScreen> with SingleTickerProviderStateMixin {
  static const _storageKey = 'viril_training_v1';
  static const _muscles = {
    'chest': 'Грудь', 'shoulders': 'Плечи', 'biceps': 'Бицепс',
    'triceps': 'Трицепс', 'forearm': 'Предплечья', 'back': 'Спина',
    'trapezius': 'Трапеции', 'lowerback': 'Поясница', 'abdomen': 'Пресс',
    'obliques': 'Косые мышцы', 'quads': 'Квадрицепсы',
    'hamstrings': 'Бицепс бедра', 'glutes': 'Ягодицы', 'calves': 'Икры',
    'cardio': 'Кардио',
  };
  static const _difficulty = {
    'Beginner': 'Начальная',
    'Intermediate': 'Средняя',
    'Advanced': 'Продвинутая',
  };
  static const _rates = {'Beginner': 1, 'Intermediate': 3, 'Advanced': 5};
  static final _staticPattern =
      RegExp(r'(hold|plank|hang|stretch|pose|carry|walk|run|cycling|swimming|erg|trainer)', caseSensitive: false);

  late final TabController _tabs;
  final _searchController = TextEditingController();
  List<TrainingExercise> _exercises = [];
  List<Map<String, dynamic>> _programs = [];
  Map<String, dynamic> _training = {
    'xp': 0, 'workouts': 0, 'totalReps': 0,
    'history': <dynamic>[], 'queue': <dynamic>[], 'sessionStarted': null,
  };
  String _muscle = 'all';
  String _difficultyFilter = '';
  String _equipmentFilter = '';
  int _catalogLimit = 48;
  bool _loading = true;
  int _artImportedCount = 0;
  String? _loadError;

  List<Map<String, dynamic>> get _queue =>
      (_training['queue'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  List<Map<String, dynamic>> get _history =>
      (_training['history'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _searchController.addListener(() => setState(() => _catalogLimit = 48));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final exerciseJson = jsonDecode(
        await rootBundle.loadString('assets/data/exercises.json'),
      ) as List;
      final programJson = jsonDecode(
        await rootBundle.loadString('assets/data/programs.json'),
      ) as List;
      final prefs = await SharedPreferences.getInstance();
      _artImportedCount = prefs.getInt('viril_art_asset_count') ?? 0;
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is Map) _training = {..._training, ...Map<String, dynamic>.from(saved)};
      }
      _exercises = exerciseJson
          .whereType<Map>()
          .map((e) => TrainingExercise.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _programs = programJson
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (error) {
      _loadError = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_training));
    if (mounted) setState(() {});
  }


  Future<void> _importAnimations() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Не удалось прочитать выбранный архив.');
      }
      final count = await ArtArchiveImporter.importBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('viril_art_asset_count', count);
      if (!mounted) return;
      setState(() => _artImportedCount = count);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Подключено векторных анимаций: $count')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось импортировать архив: $error')),
      );
    }
  }

  String _normal(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  List<TrainingExercise> get _filtered {
    final query = _normal(_searchController.text);
    return _exercises.where((exercise) {
      final matchesMuscle = _muscle == 'all' || exercise.primary == _muscle;
      final matchesSearch = query.isEmpty ||
          _normal(exercise.name).contains(query) ||
          _normal(exercise.primary).contains(query) ||
          exercise.aliases.any((a) => _normal(a).contains(query));
      final matchesDifficulty =
          _difficultyFilter.isEmpty || exercise.difficulty == _difficultyFilter;
      final matchesEquipment =
          _equipmentFilter.isEmpty || exercise.equipment == _equipmentFilter;
      return matchesMuscle && matchesSearch && matchesDifficulty && matchesEquipment;
    }).toList();
  }


  TrainingExercise? _findProgramExercise(String id) {
    final normalized = _normal(id.replaceAll('-', ' '));
    for (final exercise in _exercises) {
      if (exercise.id == id ||
          exercise.art == id ||
          exercise.aliases.contains(id) ||
          _normal(exercise.name) == normalized) {
        return exercise;
      }
    }
    return null;
  }

  TrainingExercise? _findExerciseById(String id) {
    for (final exercise in _exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  int _rate(TrainingExercise exercise) => _rates[exercise.difficulty] ?? 1;
  bool _isStatic(TrainingExercise exercise) =>
      _staticPattern.hasMatch(exercise.name);

  Future<void> _openExercise(TrainingExercise exercise) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VirilTheme.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                )),
                const SizedBox(height: 18),
                Container(
                  height: 150, width: double.infinity,
                  decoration: BoxDecoration(
                    color: VirilTheme.background,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: ArtAnimationWidget(slug: exercise.art, size: 142),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_muscles[exercise.primary] ?? exercise.primary.toUpperCase(),
                  style: const TextStyle(color: VirilTheme.blue, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 5),
                Text(exercise.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _tag(_difficulty[exercise.difficulty] ?? exercise.difficulty),
                  _tag(exercise.equipment),
                  _tag('${_rate(exercise)} XP / повтор'),
                ]),
                const SizedBox(height: 18),
                const Text('ТЕХНИКА ВЫПОЛНЕНИЯ',
                  style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                for (var i = 0; i < exercise.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 23, height: 23, alignment: Alignment.center,
                        decoration: BoxDecoration(color: VirilTheme.background, borderRadius: BorderRadius.circular(8)),
                        child: Text('${i + 1}', style: const TextStyle(color: VirilTheme.blue, fontSize: 11)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(exercise.steps[i],
                        style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 13))),
                    ]),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _addToQueue(exercise);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить в тренировку'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: VirilTheme.background, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  );

  Future<void> _addToQueue(TrainingExercise exercise, {int sets = 3, int reps = 10}) async {
    final queue = _queue;
    if (queue.any((item) => item['exerciseId'] == exercise.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Это упражнение уже есть в плане')),
      );
      return;
    }
    queue.add({
      'exerciseId': exercise.id,
      'name': exercise.name,
      'difficulty': exercise.difficulty,
      'art': exercise.art,
      'primary': exercise.primary,
      'sets': sets,
      'reps': reps,
      'done': <int>[],
      'static': _isStatic(exercise),
    });
    _training['queue'] = queue;
    _training['sessionStarted'] ??= DateTime.now().toIso8601String();
    await _save();
    if (mounted) _tabs.animateTo(1);
  }

  Future<void> _addProgram(Map<String, dynamic> program) async {
    final ids = (program['ids'] as List? ?? const []).map((e) => e.toString());
    var added = 0;
    for (final id in ids) {
      final exercise = _findProgramExercise(id);
      if (exercise == null) continue;
      final queue = _queue;
      if (queue.any((item) => item['exerciseId'] == exercise.id)) continue;
      queue.add({
        'exerciseId': exercise.id, 'name': exercise.name,
        'difficulty': exercise.difficulty, 'art': exercise.art,
        'primary': exercise.primary, 'sets': 3, 'reps': 10,
        'done': <int>[], 'static': _isStatic(exercise),
      });
      _training['queue'] = queue;
      added++;
    }
    if (added > 0) {
      _training['sessionStarted'] ??= DateTime.now().toIso8601String();
      await _save();
      if (mounted) DefaultTabController.of(context).animateTo(1);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Упражнения этой программы не найдены в каталоге')),
      );
    }
  }

  Future<void> _completeSet(int index) async {
    final queue = _queue;
    if (index < 0 || index >= queue.length) return;
    final item = queue[index];
    final sets = max(1, (item['sets'] as num?)?.toInt() ?? 3).toInt();
    final reps = max(1, (item['reps'] as num?)?.toInt() ?? 10).toInt();
    final done = (item['done'] as List? ?? const [])
        .map((e) => (e as num).toInt()).toList();
    if (done.length >= sets) return;
    final exercise = _findExerciseById((item['exerciseId'] ?? '').toString());
    final difficulty = (item['difficulty'] ?? 'Beginner').toString();
    final base = _rates[difficulty] ?? 1;
    final isStatic = item['static'] == true;
    final units = isStatic ? (reps ~/ 10) : reps;
    final award = (max(isStatic ? 1 : 0, units * base) + 2).toInt();
    done.add(done.length);
    item['done'] = done;
    queue[index] = item;
    _training['queue'] = queue;
    _training['totalReps'] = (( _training['totalReps'] as num?)?.toInt() ?? 0) + (isStatic ? 0 : reps);
    final history = _history;
    history.insert(0, {
      'label': '${item['name']} · подход ${done.length}',
      'xp': award, 'reps': isStatic ? 0 : reps,
      'date': DateTime.now().toIso8601String(),
    });
    _training['history'] = history.take(100).toList();
    await widget.controller.awardTrainingXp(
      award,
      label: exercise?.name ?? (item['name'] ?? 'Упражнение').toString(),
      reps: isStatic ? 0 : reps,
    );
    await _save();
  }

  Future<void> _finishWorkout() async {
    final queue = _queue;
    final completed = queue.fold<int>(0, (sum, item) =>
      sum + (item['done'] as List? ?? const []).length);
    if (completed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отметь выполненный подход, чтобы завершить тренировку')),
      );
      return;
    }
    final history = _history;
    history.insert(0, {
      'label': 'Тренировка завершена',
      'xp': 15, 'reps': 0, 'date': DateTime.now().toIso8601String(),
    });
    _training['history'] = history.take(100).toList();
    _training['workouts'] = ((_training['workouts'] as num?)?.toInt() ?? 0) + 1;
    _training['queue'] = <dynamic>[];
    _training['sessionStarted'] = null;
    await widget.controller.awardTrainingXp(15, label: 'Завершение тренировки');
    await _save();
  }

  Future<void> _removeFromQueue(int index) async {
    final queue = _queue;
    queue.removeAt(index);
    _training['queue'] = queue;
    if (queue.isEmpty) _training['sessionStarted'] = null;
    await _save();
  }

  Widget _catalogTab() {
    final filtered = _filtered;
    final visible = filtered.take(_catalogLimit).toList();
    final equipment = _exercises.map((e) => e.equipment).where((e) => e.isNotEmpty).toSet().toList()..sort();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Поиск упражнения',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty ? null : IconButton(
              onPressed: _searchController.clear,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 43,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: [
            _muscleChip('all', 'Все'),
            for (final entry in _muscles.entries) _muscleChip(entry.key, entry.value),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 3, 14, 8),
        child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _difficultyFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Сложность', isDense: true),
            items: const [
              DropdownMenuItem(value: '', child: Text('Любая')),
              DropdownMenuItem(value: 'Beginner', child: Text('Начальная')),
              DropdownMenuItem(value: 'Intermediate', child: Text('Средняя')),
              DropdownMenuItem(value: 'Advanced', child: Text('Продвинутая')),
            ],
            onChanged: (value) => setState(() { _difficultyFilter = value ?? ''; _catalogLimit = 48; }),
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _equipmentFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Оборудование', isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('Любое')),
              ...equipment.map((value) => DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() { _equipmentFilter = value ?? ''; _catalogLimit = 48; }),
          )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Найдено: ${filtered.length} · показано: ${visible.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          itemCount: visible.length + (visible.length < filtered.length ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == visible.length) {
              return Center(child: TextButton(
                onPressed: () => setState(() => _catalogLimit += 48),
                child: Text('Показать ещё ${min(48, filtered.length - visible.length)}'),
              ));
            }
            final exercise = visible[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _openExercise(exercise),
                leading: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: VirilTheme.background, borderRadius: BorderRadius.circular(13)),
                  child: ArtAnimationWidget(slug: exercise.art, size: 46),
                ),
                title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('${_muscles[exercise.primary] ?? exercise.primary} · ${_difficulty[exercise.difficulty] ?? exercise.difficulty}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _muscleChip(String id, String label) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: _muscle == id,
      onSelected: (_) => setState(() { _muscle = id; _catalogLimit = 48; }),
    ),
  );

  Widget _queueTab() {
    final queue = _queue;
    if (queue.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.playlist_add_rounded, color: VirilTheme.blue, size: 48),
          const SizedBox(height: 12),
          const Text('Тренировка пока пустая', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('Выбери упражнения в каталоге и добавь их в свой план.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => _tabs.animateTo(0),
            child: const Text('Открыть каталог')),
        ]),
      ));
    }
    final completed = queue.fold<int>(0, (sum, item) => sum + (item['done'] as List? ?? const []).length);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: _stat('Упражнений', '${queue.length}')),
            Expanded(child: _stat('Подходов', '$completed')),
            Expanded(child: _stat('Тренировок', '${_training['workouts'] ?? 0}')),
          ]),
        )),
        for (var i = 0; i < queue.length; i++) _queueCard(queue[i], i),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _finishWorkout,
          icon: const Icon(Icons.flag_rounded),
          label: const Text('Завершить тренировку · +15 XP'),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
    const SizedBox(height: 3),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ]);

  Widget _queueCard(Map<String, dynamic> item, int index) {
    final sets = max(1, (item['sets'] as num?)?.toInt() ?? 3);
    final reps = max(1, (item['reps'] as num?)?.toInt() ?? 10);
    final done = (item['done'] as List? ?? const []).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${index + 1}. ${item['name'] ?? 'Упражнение'}',
              style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => _removeFromQueue(index),
              icon: const Icon(Icons.close, size: 18, color: Colors.white54)),
          ]),
          Text('${_muscles[(item['primary'] ?? '').toString()] ?? item['primary'] ?? ''} · $done / $sets подходов',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            Text(item['static'] == true ? 'Секунды' : 'Повторения',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: reps <= 1 ? null : () => _changeReps(index, reps - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$reps', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _changeReps(index, reps + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            for (var j = 0; j < sets; j++)
              Expanded(child: Container(
                margin: const EdgeInsets.only(right: 5),
                height: 5,
                decoration: BoxDecoration(
                  color: j < done ? VirilTheme.blue : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
              )),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: done >= sets ? null : () => _completeSet(index),
              child: Text(done >= sets ? 'Все подходы отмечены' : 'Отметить подход · XP'),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _changeReps(int index, int reps) async {
    final queue = _queue;
    queue[index]['reps'] = reps.clamp(1, 999);
    _training['queue'] = queue;
    await _save();
  }

  Widget _programsTab() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      const Text('ГОТОВЫЕ ПЛАНЫ', style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      for (final program in _programs)
        Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.calendar_month_rounded, color: VirilTheme.blue),
            title: Text((program['name'] ?? 'Программа').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text((program['description'] ?? '').toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.add_circle_outline, color: VirilTheme.blue),
            onTap: () => _addProgram(program),
          ),
        ),
    ],
  );

  Widget _historyTab() {
    final history = _history;
    if (history.isEmpty) {
      return const Center(child: Text('История тренировок появится здесь',
        style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: min(50, history.length),
      itemBuilder: (context, index) {
        final item = history[index];
        DateTime? date;
        try { date = DateTime.parse((item['date'] ?? '').toString()); } catch (_) {}
        return Card(
          margin: const EdgeInsets.only(bottom: 7),
          child: ListTile(
            leading: const Icon(Icons.bolt_rounded, color: Color(0xFFF4C96B)),
            title: Text((item['label'] ?? 'Тренировка').toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: Text(date == null ? '' : date.toLocal().toString().substring(0, 16),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
            trailing: Text('+ ${item['xp'] ?? 0} XP',
              style: const TextStyle(color: VirilTheme.blue, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(title: const Text('Viril Training')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Не удалось загрузить каталог: $_loadError'),
        )));
    }
    return Scaffold(
        appBar: AppBar(
          title: const Text('Viril Training', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: _artImportedCount > 0
                  ? 'Подключено анимаций: $_artImportedCount. Нажми, чтобы импортировать ещё'
                  : 'Импортировать векторные анимации',
              onPressed: _importAnimations,
              icon: const Icon(Icons.animation_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              const Tab(text: 'Каталог'),
              const Tab(text: 'Мой план'),
              const Tab(text: 'Программы'),
              const Tab(text: 'История'),
            ],
          ),
        ),
        body: TabBarView(controller: _tabs, children: [
          _catalogTab(),
          _queueTab(),
          _programsTab(),
          _historyTab(),
        ]),
      );
  }
}
