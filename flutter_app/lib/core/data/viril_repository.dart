import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/viril_state.dart';

/// Persistence adapter for the original Viril v1 contract:
/// local key: viril_self_development_v1
/// training module key: viril_training_v1
/// cloud table: public.game_saves (user_id, save_data, updated_at)
class VirilRepository {
  VirilRepository(this.client);
  final SupabaseClient client;
  SharedPreferences? _preferences;
  Timer? _saveTimer;
  bool cloudReady = false;

  static const _legacyStateKey = VirilState.storageKey;
  static const _legacyTrainingKey = 'viril_training_v1';
  static const _legacyAuthKey = 'sb-pjewrbblgnchzlznlpld-auth-token';

  User? get user => client.auth.currentUser;
  bool get isAnonymous => user?.isAnonymous ?? true;
  bool get isRegistered => user != null && !isAnonymous;

  Future<VirilState> initialize({
    Map<String, String> legacyStorage = const {},
  }) async {
    _preferences = await SharedPreferences.getInstance();
    final prefs = _preferences!;

    // Prefer the Flutter save if it already exists. On the first Flutter
    // launch, import the exact localStorage JSON from the old Capacitor app.
    final localRaw = prefs.getString(_legacyStateKey);
    final legacyRaw = legacyStorage[_legacyStateKey];
    var state = _decodeState(localRaw ?? legacyRaw);
    if (localRaw == null && legacyRaw != null) {
      await prefs.setString(_legacyStateKey, legacyRaw);
    }

    // The old 448-exercise module kept its own local progress key.
    final trainingRaw = legacyStorage[_legacyTrainingKey];
    if (prefs.getString(_legacyTrainingKey) == null && trainingRaw != null) {
      await prefs.setString(_legacyTrainingKey, trainingRaw);
    }

    // Restore the existing Supabase JS session before creating a new guest.
    // This preserves the old anonymous/Google-linked user_id and cloud save.
    try {
      final rawAuth = legacyStorage[_legacyAuthKey];
      final existingUser = client.auth.currentUser;
      if (rawAuth != null && (existingUser == null || existingUser.isAnonymous)) {
        final decoded = jsonDecode(rawAuth);
        final refreshToken = decoded is Map
            ? decoded['refresh_token']?.toString()
            : null;
        if (refreshToken != null && refreshToken.isNotEmpty) {
          if (existingUser != null) await client.auth.signOut();
          await client.auth.setSession(refreshToken);
        }
      }
    } catch (_) {
      // If the old session expired, continue with the local save and guest mode.
    }

    try {
      var session = client.auth.currentSession;
      if (session == null) {
        final response = await client.auth.signInAnonymously();
        session = response.session;
      }
      if (session != null) {
        final row = await client
            .from('game_saves')
            .select('save_data')
            .eq('user_id', session.user.id)
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
    } catch (_) {
      // Offline startup must never block access to the local save.
      cloudReady = false;
    }
    return state;
  }

  VirilState _decodeState(String? raw) {
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
    await prefs.setString(_legacyStateKey, jsonEncode(state.toJsonMap()));
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
    await prefs.setString(_legacyStateKey, jsonEncode(state.toJsonMap()));
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
    // Link Google to the existing guest user instead of making a second
    // account, exactly as the old web app did.
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
