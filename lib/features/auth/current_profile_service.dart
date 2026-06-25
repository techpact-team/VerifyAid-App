import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/storage/offline_cache_service.dart';

class CurrentProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();

    debugPrint('PROFILE SERVICE hasInternet: $hasInternet');

    if (!hasInternet) {
      final cachedProfile = await OfflineCacheService.getCachedProfile();

      debugPrint('PROFILE SERVICE offline cached profile: $cachedProfile');

      return cachedProfile;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      final cachedProfile = await OfflineCacheService.getCachedProfile();

      debugPrint('PROFILE SERVICE no Supabase user. Using cache.');

      return cachedProfile;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, tenant_id, role_id, location_id, status',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final mappedProfile = Map<String, dynamic>.from(profile);

        await OfflineCacheService.saveCachedProfile(mappedProfile);

        debugPrint('PROFILE SERVICE online profile cached: $mappedProfile');

        return mappedProfile;
      }

      return OfflineCacheService.getCachedProfile();
    } catch (e) {
      debugPrint('PROFILE SERVICE online error: $e');

      return OfflineCacheService.getCachedProfile();
    }
  }
}