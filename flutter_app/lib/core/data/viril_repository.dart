import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/viril_state.dart';

/// Persistence adapter for the original Viril v1 contract:
/// local key: viril_self_development_v1
/// cloud table: public.game_saves (user_id, save_data, updated_at)
class VirilRepository {
  VirilRepository(this.client);
  final SupabaseClient client;
  SharedPreferences? _preferences;
  Timer? _saveTimer;
  bool cloudReady = false;

  User? get user => client.auth.currentUser;
  bool get isAnonymous => user?.isAnonymous ?? true;
  bool get isRegistered => user != null && !isAnonymous;

  Future<VirilState> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    var state = _readLocal();

    try {
      var session = client.auth.currentSession;
      if (session == null) {
        final response = await client.auth.signInAnonymously();
        session = response.session;
      }
      if (session != null) {
        final userId = session.user.id;
        final row = await client
            .from('game_saves')
            .select('save_data')
            .eq('user_id', userId)
            .maybeSingle();
        final cloudData = row?['save_data'];
        if (cloudData is Map) {
          // Preserve the v1 merge order: cloud fields override local fields,
          // while local-only keys absent from the cloud snapshot survive.
          state = VirilState({
            ...state.data,
            ...Map<String, dynamic>.from(cloudData),
          });
          state.normalize();
        }
        cloudReady = true;
        await saveNow(state);
      }
    } catch (error) {
      // Offline startup must never block access to the local save.
      cloudReady = false;
    }
    return state;
  }

  VirilState _readLocal() {
    final raw = _preferences?.getString(VirilState.storageKey);
    if (raw == null || raw.isEmpty) return VirilState.defaults();
    try {
      return VirilState.fromJson(raw);
    } catch (_) {
      return VirilState.defaults();
    }
  }

  Future<void> save(VirilState state) async {
    state.normalize();
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setString(VirilState.storageKey, jsonEncode(state.toJsonMap()));
    _saveTimer?.cancel();
    if (cloudReady) {
      _saveTimer = Timer(const Duration(milliseconds: 250), () {
        saveCloudNow(state);
      });
    }
  }

  Future<bool> saveNow(VirilState state) async {
    state.normalize();
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setString(VirilState.storageKey, jsonEncode(state.toJsonMap()));
    return saveCloudNow(state);
  }

  Future<bool> saveCloudNow(VirilState state) async {
    final current = user;
    if (!cloudReady || current == null) return false;
    _saveTimer?.cancel();
    try {
      await client.from('game_saves').upsert({
        'user_id': current.id,
        'save_data': state.toJsonMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> linkGoogleIdentity() async {
    if (user == null) {
      throw StateError('Сначала создаётся гостевая сессия.');
    }
    // This intentionally links Google to the existing anonymous user instead
    // of creating a second account, matching the v1 registration flow.
    await client.auth.linkIdentity(OAuthProvider.google);
  }

  Future<void> updateProfile(String nickname, String avatar) async {
    if (!isRegistered) return;
    await client.rpc('update_my_profile', params: {
      'p_nickname': nickname,
      'p_avatar': avatar,
    });
  }

  Future<void> recordGoalCompletion({
    required String goalId,
    required int xp,
    required bool done,
  }) async {
    if (!isRegistered) return;
    await client.rpc('set_goal_completion', params: {
      'p_goal_id': goalId,
      'p_xp': xp,
      'p_done': done,
    });
  }

  Future<void> changeToGuest() async {
    await client.auth.signOut();
    await client.auth.signInAnonymously();
    cloudReady = true;
  }

  Future<void> deleteAccount() async {
    if (!isRegistered) {
      throw StateError('Для удаления требуется аккаунт Google.');
    }
    await client.functions.invoke('delete-account');
    await client.auth.signOut();
    cloudReady = false;
  }

  void dispose() {
    _saveTimer?.cancel();
  }
}
