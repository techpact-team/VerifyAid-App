import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAssignedPrograms({
    required String tenantId,
    required String locationId,
  }) async {
    debugPrint('PROGRAM SERVICE tenantId: $tenantId');
    debugPrint('PROGRAM SERVICE locationId: $locationId');

    final response = await supabase
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

    debugPrint('PROGRAM SERVICE raw response: $response');

    final rows = List<Map<String, dynamic>>.from(response);

    final programs = rows
        .map((row) => row['programs'])
        .where((program) => program != null)
        .map((program) => Map<String, dynamic>.from(program))
        .where((program) {
          final status = program['status']?.toString().toLowerCase();
          return status == null || status == 'active';
        })
        .toList();

    debugPrint('PROGRAM SERVICE parsed programs: $programs');

    return programs;
  }
}