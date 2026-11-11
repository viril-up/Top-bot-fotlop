import 'dart:convert';
import 'dart:math';

/// Retains the complete legacy JSON document, including keys not yet used by
/// Flutter, so a newer build does not silently discard older app data.
class VirilState {
  VirilState(this.data);
  final Map<String, dynamic> data;

  static const storageKey = 'viril_self_development_v1';

  factory VirilState.defaults({DateTime? now}) {
    return VirilState({
      'xp': 0, 'level': 1, 'nickname': 'Viril', 'avatar': '🧠',
      'goals': <dynamic>[], 'lastDate': _dateKey(now ?? DateTime.now()),
      'history': <String, dynamic>{}, 'activityDays': <dynamic>[],
      'playerTag': '', 'penaltyTotal': 0, 'diary': <dynamic>[],
      'focusSessions': 0, 'language': 'ru', 'sounds': false,
    });
  }

  factory VirilState.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) throw const FormatException('Invalid Viril save');
    final result = VirilState(Map<String, dynamic>.from(decoded));
    result.normalize();
    return result;
  }

  Map<String, dynamic> toJsonMap() => Map<String, dynamic>.from(data);
  int get xp => _int(data['xp']);
  int get level => _int(data['level'], fallback: 1);
  String get nickname => (data['nickname'] ?? 'Viril').toString();
  String get avatar => (data['avatar'] ?? '🧠').toString();
  String get language => (data['language'] ?? 'ru').toString();
  List<Map<String, dynamic>> get goals => _mapList(data['goals']);
  List<Map<String, dynamic>> get futureGoals => _mapList(data['futureGoals']);
  List<Map<String, dynamic>> get diary => _mapList(data['diary']);
  Map<String, dynamic> get history => _map(data['history']);
  Map<String, dynamic> get workouts => _map(data['workouts']);
  List<String> get activityDays =>
      (data['activityDays'] as List? ?? const []).map((e) => e.toString()).toList();

  static int threshold(int value) => value <= 1 ? 0 : 100 + (value - 2) * 50;
  static String rankFor(int value) {
    if (value >= 25) return 'Легенда';
    if (value >= 15) return 'Мастер';
    if (value >= 10) return 'Элита';
    if (value >= 6) return 'Ветеран';
    if (value >= 3) return 'Воин';
    if (value >= 2) return 'Ученик';
    return 'Новичок';
  }

  int get xpIntoLevel => xp - threshold(level);
  int get xpForNextLevel => threshold(level + 1) - xp;
  double get levelProgress {
    final span = threshold(level + 1) - threshold(level);
    return span <= 0 ? 0 : (xpIntoLevel / span).clamp(0.0, 1.0);
  }

  void normalize() {
    data['xp'] = max(0, _int(data['xp']));
    var calculated = 1;
    while (calculated < 100 && data['xp'] >= threshold(calculated + 1)) {
      calculated++;
    }
    data['level'] = calculated;
    for (final key in ['goals', 'diary', 'activityDays']) {
      if (data[key] is! List) data[key] = <dynamic>[];
    }
    if (data['history'] is! Map) data['history'] = <String, dynamic>{};
    if (data['workouts'] is! Map) data['workouts'] = <String, dynamic>{};
    if (data['futureGoals'] is! List) data['futureGoals'] = <dynamic>[];
    if ((data['playerTag'] ?? '').toString().isEmpty) {
      data['playerTag'] = 'VIRIL${1000 + Random().nextInt(9000)}';
    }
    if ((data['lastDate'] ?? '').toString().isEmpty) {
      data['lastDate'] = _dateKey(DateTime.now());
    }
  }

  int currentStreak({DateTime? now}) {
    final days = activityDays.toSet();
    var cursor = _dateKey(now ?? DateTime.now());
    if (!days.contains(cursor)) {
      cursor = _dateKey((now ?? DateTime.now()).subtract(const Duration(days: 1)));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _dateKey(DateTime.parse('${cursor}T12:00:00').subtract(const Duration(days: 1)));
    }
    return streak;
  }

  void markActivity({DateTime? now}) {
    final days = activityDays;
    final key = _dateKey(now ?? DateTime.now());
    if (!days.contains(key)) days.add(key);
    data['activityDays'] = days.length > 400 ? days.sublist(days.length - 400) : days;
  }

  /// Same daily rollover, history snapshot and missed-goal penalty as web v1.
  int rollover({DateTime? now}) {
    final currentDate = _dateKey(now ?? DateTime.now());
    final lastDate = (data['lastDate'] ?? '').toString();
    if (lastDate.isEmpty) {
      data['lastDate'] = currentDate;
      return 0;
    }
    if (lastDate == currentDate) return 0;
    final oldGoals = goals;
    final completed = oldGoals.where((goal) => goal['done'] == true).toList();
    var penalty = 0;
    for (final goal in oldGoals) {
      if (goal['done'] != true && goal['penaltyApplied'] != true) {
        penalty += _int(goal['penalty'], fallback: 5).clamp(5, 10);
        goal['penaltyApplied'] = true;
      }
    }
    final earned = completed.fold<int>(0, (sum, goal) => sum + _int(goal['xp']));
    final workout = workouts[lastDate];
    final workoutEarned = workout is Map ? _int(workout['xp']) : 0;
    history[lastDate] = {
      'date': lastDate,
      'goals': oldGoals.map((g) => Map<String, dynamic>.from(g)).toList(),
      'done': completed.length, 'total': oldGoals.length, 'earned': earned,
      'penalty': penalty, 'score': (earned + workoutEarned).clamp(0, 100),
      'net': earned - penalty,
    };
    data['xp'] = max(0, xp - penalty);
    data['penaltyTotal'] = _int(data['penaltyTotal']) + penalty;
    data['goals'] = <dynamic>[];
    data['lastDate'] = currentDate;
    normalize();
    return penalty;
  }

  void addGoal({
    required String id, required String text, required int rewardXp,
    required int penalty, required String period, DateTime? now,
  }) {
    final goal = <String, dynamic>{
      'id': id, 'text': text, 'xp': rewardXp, 'penalty': penalty,
      'done': false, 'created': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'period': period,
    };
    if (period == 'day') {
      final items = goals..add(goal);
      data['goals'] = items;
    } else {
      final items = futureGoals..add(goal);
      data['futureGoals'] = items;
    }
  }

  /// Returns the XP delta; negative when a completed goal is unchecked.
  int toggleGoal(String id, {DateTime? now}) {
    final items = goals;
    final index = items.indexWhere((goal) => goal['id'].toString() == id);
    if (index < 0) return 0;
    final goal = items[index];
    final reward = _int(goal['xp']);
    if (goal['done'] == true) {
      goal['done'] = false;
      data['xp'] = max(0, xp - reward);
      data['goals'] = items;
      normalize();
      return -reward;
    }
    goal['done'] = true;
    data['xp'] = xp + reward;
    data['goals'] = items;
    markActivity(now: now);
    normalize();
    return reward;
  }

  void addDiaryEntry(String text, {String audio = '', DateTime? now}) {
    final items = diary;
    items.add({
      'id': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'date': _dateKey(now ?? DateTime.now()), 'text': text, 'audio': audio,
    });
    data['diary'] = items;
  }

  /// Existing workout rule: +3 XP per set, maximum 45 XP each day.
  int logWorkoutSet({required String exerciseId, required int reps, DateTime? now}) {
    final date = _dateKey(now ?? DateTime.now());
    final all = workouts;
    final existing = all[date];
    final day = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{'sets': <dynamic>[], 'xp': 0};
    final sets = (day['sets'] as List? ?? <dynamic>[]).toList();
    final gain = min(3, max(0, 45 - _int(day['xp'])));
    sets.add({
      'e': exerciseId, 'r': reps.clamp(1, 100),
      't': (now ?? DateTime.now()).millisecondsSinceEpoch,
    });
    day['sets'] = sets;
    day['xp'] = _int(day['xp']) + gain;
    all[date] = day;
    data['workouts'] = all;
    data['xp'] = xp + gain;
    markActivity(now: now);
    normalize();
    return gain;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  static int _int(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? fallback;
  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
