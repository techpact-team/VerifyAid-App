import 'package:supabase_flutter/supabase_flutter.dart';

import '../biometrics/biometric_service.dart';

class DistributionService {
  final supabase = Supabase.instance.client;
  final biometricService = BiometricService();

  Future<List<Map<String, dynamic>>> searchBeneficiaries(String query) async {
    final response = await supabase
        .from('beneficiaries')
        .select()
        .or(
          'full_name.ilike.%$query%,phone.ilike.%$query%,national_id.ilike.%$query%',
        )
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String?> getRegisteredFaceUrl(String beneficiaryId) async {
    return biometricService.getSignedFacePhotoUrl(beneficiaryId);
  }

  Future<bool> verifyFingerprint(String beneficiaryId) async {
    return biometricService.verifySimulatedFingerprint(beneficiaryId);
  }

  Future<void> recordDistribution({
    required String beneficiaryId,
    required String programId,
  }) async {
    final user = supabase.auth.currentUser!;

    await supabase.from('distribution_events').insert({
      'beneficiary_id': beneficiaryId,
      'program_id': programId,
      'distributed_by': user.id,
      'status': 'completed',
      'quantity': 1,
      'item_name': 'Fertilizer',
    });
  }
}