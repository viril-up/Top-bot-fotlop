import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:viril/core/models/viril_state.dart';

void main() {
  group('Viril legacy state compatibility', () {
    test('keeps legacy keys that Flutter has not migrated yet', () {
      final state = VirilState.fromJson(jsonEncode({
        'xp': 680,
        'nickname': 'Viril Player',
        'futureGoals': [{'id': 'future-1', 'period': 'week'}],
        'soundVolume': 0.25,
        'customLegacyField': {'enabled': true},
      }));

      expect(state.xp, 680);
      expect(state.level, 13);
      expect(state.data['futureGoals'], isNotEmpty);
      expect(state.data['soundVolume'], 0.25);
      expect(state.data['customLegacyField']['enabled'], isTrue);
    });

    test('uses the same level thresholds and ranks as v1', () {
      final state = VirilState({'xp': 680});
      state.normalize();

      expect(state.level, 13);
      expect(VirilState.threshold(2), 100);
      expect(VirilState.threshold(3), 150);
      expect(VirilState.rankFor(4), 'Воин');
      expect(state.xpForNextLevel, 20);
    });

    test('goal completion awards XP and undo reverses it', () {
      final state = VirilState.defaults(now: DateTime(2026, 11, 11));
      state.addGoal(
        id: 'goal-1',
        text: 'Чтение',
        rewardXp: 10,
        penalty: 5,
        period: 'day',
        now: DateTime(2026, 11, 11),
      );

      expect(state.toggleGoal('goal-1', now: DateTime(2026, 11, 11)), 10);
      expect(state.xp, 10);
      expect(state.goals.single['done'], isTrue);
      expect(state.toggleGoal('goal-1', now: DateTime(2026, 11, 11)), -10);
      expect(state.xp, 0);
      expect(state.goals.single['done'], isFalse);
    });

    test('workout XP keeps the original daily cap of 45', () {
      final state = VirilState.defaults(now: DateTime(2026, 11, 11));
      var total = 0;
      for (var i = 0; i < 20; i++) {
        total += state.logWorkoutSet(
          exerciseId: 'pushup',
          reps: 10,
          now: DateTime(2026, 11, 11),
        );
      }
      expect(total, 45);
      expect(state.xp, 45);
      expect((state.workouts['2026-11-11'] as Map)['sets'], hasLength(20));
    });

    test('daily rollover records the previous day before clearing goals', () {
      final state = VirilState({
        'xp': 20,
        'lastDate': '2026-11-10',
        'goals': [
          {'id': 'done', 'text': 'Done', 'xp': 10, 'penalty': 5, 'done': true},
          {'id': 'missed', 'text': 'Missed', 'xp': 10, 'penalty': 5, 'done': false},
        ],
        'history': {},
        'workouts': {},
        'activityDays': [],
        'diary': [],
      });

      final penalty = state.rollover(now: DateTime(2026, 11, 11));

      expect(penalty, 5);
      expect(state.xp, 15);
      expect(state.goals, isEmpty);
      expect(state.data['history']['2026-11-10']['done'], 1);
      expect(state.data['history']['2026-11-10']['penalty'], 5);
      expect(state.data['lastDate'], '2026-11-11');
    });
  });
}
