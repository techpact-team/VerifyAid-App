import 'package:supabase_flutter/supabase_flutter.dart';

class DistributionService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchBeneficiaries({
    required String query,
    required String tenantId,
    required String locationId,
  }) async {
    final response = await supabase
        .from('beneficiaries')
        .select()
        .eq('tenant_id', tenantId)
        .eq('location_id', locationId)
        .or(
          'full_name.ilike.%$query%,phone.ilike.%$query%,national_id.ilike.%$query%',
        )
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<bool> hasReceivedAidAlready({
    required String beneficiaryId,
    required String programId,
  }) async {
    final existing = await supabase
        .from('distribution_events')
        .select('id')
        .eq('beneficiary_id', beneficiaryId)
        .eq('program_id', programId)
        .eq('status', 'completed')
        .maybeSingle();

    return existing != null;
  }

  Future<String> recordDistributionSuccess({
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
    required String itemName,
    required num quantity,
    required String verificationMethod,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final response = await supabase
        .from('distribution_events')
        .insert({
          'tenant_id': tenantId,
          'program_id': programId,
          'beneficiary_id': beneficiaryId,
          'location_id': locationId,
          'distributed_by': user.id,
          'item_name': itemName,
          'quantity': quantity,
          'status': 'completed',
          'distributed_at': DateTime.now().toIso8601String(),
          'verification_method': verificationMethod,
          'verification_status': 'matched',
          'metadata': {
            'source': 'flutter_mobile',
            'flow': 'distribution_verification',
          },
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<String> recordDistributionRejected({
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
    required String reason,
    required String verificationMethod,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final response = await supabase
        .from('distribution_events')
        .insert({
          'tenant_id': tenantId,
          'program_id': programId,
          'beneficiary_id': beneficiaryId,
          'location_id': locationId,
          'distributed_by': user.id,
          'item_name': null,
          'quantity': 0,
          'status': 'rejected',
          'distributed_at': DateTime.now().toIso8601String(),
          'verification_method': verificationMethod,
          'verification_status': 'failed',
          'rejection_reason': reason,
          'metadata': {
            'source': 'flutter_mobile',
            'flow': 'distribution_verification',
          },
        })
        .select('id')
        .single();

    return response['id'] as String;
  }
}
