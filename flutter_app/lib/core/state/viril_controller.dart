import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/viril_repository.dart';
import '../models/viril_state.dart';

class VirilController extends ChangeNotifier {
  VirilController(this.repository);

  final VirilRepository repository;
  VirilState state = VirilState.defaults();
  bool initialized = false;
  bool cloudAvailable = false;
  String? lastError;

  bool get isRegistered => repository.isRegistered;
  bool get isAnonymous => repository.isAnonymous;

  Future<void> initialize() async {
    try {
      state = await repository.initialize();
      final penalty = state.rollover();
      if (penalty > 0) await repository.saveNow(state);
      cloudAvailable = repository.cloudReady;
    } catch (error) {
      lastError = error.toString();
      cloudAvailable = false;
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> persist({bool immediate = false}) async {
    notifyListeners();
    if (immediate) {
      await repository.saveNow(state);
    } else {
      await repository.save(state);
    }
    cloudAvailable = repository.cloudReady;
  }

  Future<void> addGoal({
    required String text,
    required String period,
    required int rewardXp,
    required int penalty,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${Random().nextInt(0x7fffffff).toRadixString(36)}';
    state.addGoal(
      id: id,
      text: text.trim(),
      rewardXp: rewardXp,
      penalty: penalty,
      period: period,
    );
    await persist();
  }

  Future<void> toggleGoal(String id) async {
    final goal = state.goals.where((item) => item['id'].toString() == id);
    if (goal.isEmpty) return;
    final wasDone = goal.first['done'] == true;
    final reward = (goal.first['xp'] as num?)?.toInt() ?? 0;
    state.toggleGoal(id);
    await persist(immediate: true);
    try {
      await repository.recordGoalCompletion(
        goalId: id,
        xp: reward,
        done: !wasDone,
      );
    } catch (error) {
      lastError = error.toString();
    }
  }

  Future<void> addDiaryEntry(String text) async {
    if (text.trim().isEmpty) return;
    state.addDiaryEntry(text.trim());
    await persist();
  }

  Future<int> logWorkoutSet({
    required String exerciseId,
    required int reps,
  }) async {
    final gained = state.logWorkoutSet(exerciseId: exerciseId, reps: reps);
    await persist(immediate: true);
    return gained;
  }

  Future<void> updateProfile({
    required String nickname,
    required String avatar,
  }) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return;
    state.data['nickname'] = clean.substring(0, clean.length.clamp(0, 24));
    state.data['avatar'] = avatar;
    await persist(immediate: true);
    try {
      await repository.updateProfile(state.nickname, state.avatar);
    } catch (error) {
      lastError = error.toString();
    }
  }

  Future<void> linkGoogle() async {
    await repository.linkGoogleIdentity();
    cloudAvailable = repository.cloudReady;
    notifyListeners();
  }

  Future<void> changeAccount() async {
    await repository.saveNow(state);
    await repository.changeToGuest();
    cloudAvailable = repository.cloudReady;
    await persist(immediate: true);
  }

  Future<void> resetProgress() async {
    final language = state.language;
    state = VirilState.defaults();
    state.data['language'] = language;
    await persist(immediate: true);
  }

  Future<void> deleteAccount() async {
    await repository.deleteAccount();
    state = VirilState.defaults();
    cloudAvailable = false;
    await persist();
  }

  Future<void> setLanguage(String language) async {
    state.data['language'] = language;
    await persist();
  }

  Future<void> setSounds(bool enabled) async {
    state.data['sounds'] = enabled;
    await persist();
  }

  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }
}
