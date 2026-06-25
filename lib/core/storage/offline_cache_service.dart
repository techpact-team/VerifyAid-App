import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static const String _cachedUserKey = 'verifyaid_cached_user';
  static const String _cachedProfileKey = 'verifyaid_cached_profile';
  static const String _cachedProgramsKey = 'verifyaid_cached_programs';
  static const String _offlineEnabledKey = 'verifyaid_offline_enabled';

  static String _questionnaireKey(String programId) {
    return 'verifyaid_cached_questionnaire_$programId';
  }

  // ----------------------------
  // USER CACHE
  // ----------------------------

  static Future<void> saveCachedUser({
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cachedUserKey,
      jsonEncode({
        'id': userId,
        'email': email,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );

    await prefs.setBool(_offlineEnabledKey, true);
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------
  // PROFILE CACHE
  // ----------------------------

  static Future<void> saveCachedProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cachedProfileKey,
      jsonEncode(profile),
    );

    await prefs.setBool(_offlineEnabledKey, true);
  }

  static Future<Map<String, dynamic>?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedProfileKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------
  // PROGRAM CACHE
  // ----------------------------

  static Future<void> saveCachedPrograms(
    List<Map<String, dynamic>> programs,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cachedProgramsKey,
      jsonEncode(programs),
    );

    await prefs.setBool(_offlineEnabledKey, true);
  }

  static Future<List<Map<String, dynamic>>> getCachedPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedProgramsKey);

    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ----------------------------
  // QUESTIONNAIRE CACHE
  // ----------------------------

  static Future<void> saveCachedQuestionnaire({
    required String programId,
    required Map<String, dynamic> questionnaire,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _questionnaireKey(programId),
      jsonEncode({
        ...questionnaire,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );

    await prefs.setBool(_offlineEnabledKey, true);
  }

  static Future<Map<String, dynamic>?> getCachedQuestionnaire({
    required String programId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_questionnaireKey(programId));

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------
  // OFFLINE STATUS
  // ----------------------------

  static Future<bool> isOfflineEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineEnabledKey) ?? false;
  }

  static Future<void> clearOfflineCache() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_cachedUserKey);
    await prefs.remove(_cachedProfileKey);
    await prefs.remove(_cachedProgramsKey);
    await prefs.remove(_offlineEnabledKey);

    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('verifyaid_cached_questionnaire_')) {
        await prefs.remove(key);
      }
    }
  }

  static Future<void> debugPrintCache() async {
    final user = await getCachedUser();
    final profile = await getCachedProfile();
    final programs = await getCachedPrograms();

    // ignore: avoid_print
    print('OFFLINE CACHE user: $user');

    // ignore: avoid_print
    print('OFFLINE CACHE profile: $profile');

    // ignore: avoid_print
    print('OFFLINE CACHE programs: $programs');

    for (final program in programs) {
      final programId = program['id']?.toString();

      if (programId == null) {
        continue;
      }

      final questionnaire = await getCachedQuestionnaire(programId: programId);

      // ignore: avoid_print
      print('OFFLINE CACHE questionnaire for $programId: $questionnaire');
    }
  }
}