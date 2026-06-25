import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/storage/offline_cache_service.dart';
import '../questionnaires/questionnaire_service.dart';

class AuthResult {
  final bool success;
  final bool offline;
  final String? message;

  const AuthResult({
    required this.success,
    required this.offline,
    this.message,
  });
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return const AuthResult(
        success: false,
        offline: false,
        message: 'Enter email and password.',
      );
    }

    final hasInternet = await ConnectivityService.hasInternetConnection();

    debugPrint('AUTH SERVICE hasInternet: $hasInternet');

    if (!hasInternet) {
      return _offlineLogin(email: cleanEmail);
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final user = response.user;

      if (user == null) {
        return const AuthResult(
          success: false,
          offline: false,
          message: 'Login failed. No user was returned.',
        );
      }

      await OfflineCacheService.saveCachedUser(
        userId: user.id,
        email: user.email ?? cleanEmail,
      );

      await _cacheProfileAndPrograms(user.id);

      return const AuthResult(
        success: true,
        offline: false,
        message: 'Login successful.',
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        offline: false,
        message: e.message,
      );
    } catch (e) {
      debugPrint('AUTH SERVICE online login error: $e');

      final fallback = await _offlineLogin(email: cleanEmail);

      if (fallback.success) {
        return const AuthResult(
          success: true,
          offline: true,
          message: 'Internet failed. Offline mode active.',
        );
      }

      return const AuthResult(
        success: false,
        offline: false,
        message:
            'Unable to login online. Connect to internet once before using offline mode.',
      );
    }
  }

  Future<AuthResult> _offlineLogin({
    required String email,
  }) async {
    final offlineEnabled = await OfflineCacheService.isOfflineEnabled();
    final cachedUser = await OfflineCacheService.getCachedUser();
    final cachedProfile = await OfflineCacheService.getCachedProfile();

    if (!offlineEnabled || cachedUser == null || cachedProfile == null) {
      return const AuthResult(
        success: false,
        offline: true,
        message:
            'Offline login is not ready. Login once with internet before using offline mode.',
      );
    }

    final cachedEmail = cachedUser['email']?.toString().trim().toLowerCase();
    final enteredEmail = email.trim().toLowerCase();

    if (cachedEmail != enteredEmail) {
      return AuthResult(
        success: false,
        offline: true,
        message:
            'This device is cached for $cachedEmail. Login online first for this account.',
      );
    }

    return const AuthResult(
      success: true,
      offline: true,
      message: 'Offline mode active.',
    );
  }

  Future<void> _cacheProfileAndPrograms(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, tenant_id, role_id, location_id, status',
          )
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        debugPrint('AUTH SERVICE cache: profile not found.');
        return;
      }

      final mappedProfile = Map<String, dynamic>.from(profile);

      await OfflineCacheService.saveCachedProfile(mappedProfile);

      final tenantId = mappedProfile['tenant_id']?.toString();
      final locationId = mappedProfile['location_id']?.toString();

      if (tenantId == null || tenantId.isEmpty) {
        debugPrint('AUTH SERVICE cache: tenant_id missing.');
        return;
      }

      if (locationId == null || locationId.isEmpty) {
        debugPrint('AUTH SERVICE cache: location_id missing.');
        return;
      }

      final rows = await _supabase
          .from('program_locations')
          .select('''
            id,
            tenant_id,
            location_id,
            programs (
              id,
              name,
              description,
              tenant_id,
              status
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('location_id', locationId);

      final programs = <Map<String, dynamic>>[];

      for (final row in rows) {
        final program = row['programs'];

        if (program == null) {
          continue;
        }

        final mappedProgram = Map<String, dynamic>.from(program);
        final status = mappedProgram['status']?.toString() ?? 'active';

        if (status == 'active') {
          programs.add(mappedProgram);
        }
      }

      await OfflineCacheService.saveCachedPrograms(programs);

      final questionnaireService = QuestionnaireService();

      for (final program in programs) {
        final programId = program['id']?.toString();

        if (programId == null || programId.isEmpty) {
          continue;
        }

        await questionnaireService.cacheQuestionnaireForProgram(
          programId: programId,
          tenantId: tenantId,
        );
      }

      debugPrint('AUTH SERVICE cached profile: $mappedProfile');
      debugPrint('AUTH SERVICE cached programs: $programs');
    } catch (e) {
      debugPrint('AUTH SERVICE cache error: $e');
    }
  }
}