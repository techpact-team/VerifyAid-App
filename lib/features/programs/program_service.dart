import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/storage/offline_cache_service.dart';

class ProgramService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAssignedPrograms({
    required String tenantId,
    required String locationId,
  }) async {
    debugPrint('PROGRAM SERVICE tenantId: $tenantId');
    debugPrint('PROGRAM SERVICE locationId: $locationId');

    final hasInternet = await ConnectivityService.hasInternetConnection();

    debugPrint('PROGRAM SERVICE hasInternet: $hasInternet');

    if (!hasInternet) {
      final cachedPrograms = await OfflineCacheService.getCachedPrograms();

      debugPrint('PROGRAM SERVICE offline cached programs: $cachedPrograms');

      return cachedPrograms;
    }

    try {
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

      debugPrint('PROGRAM SERVICE raw response: $rows');

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

      debugPrint('PROGRAM SERVICE parsed programs: $programs');

      return programs;
    } catch (e) {
      debugPrint('PROGRAM SERVICE online error: $e');

      final cachedPrograms = await OfflineCacheService.getCachedPrograms();

      debugPrint('PROGRAM SERVICE fallback cached programs: $cachedPrograms');

      return cachedPrograms;
    }
  }
}