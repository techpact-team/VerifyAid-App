import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> enrollFacePhoto({
    required String beneficiaryId,
    required String tenantId,
    required String photoUrl,
    double? qualityScore,
  }) async {
    await _client.from('biometric_enrollments').insert({
      'beneficiary_id': beneficiaryId,
      'tenant_id': tenantId,
      'biometric_type': 'face',
      'provider': 'google_mlkit_face_detection',
      'template_id': 'face_${DateTime.now().millisecondsSinceEpoch}',
      'template_data': photoUrl,
      'quality_score': (qualityScore ?? 85).round(),
      'status': 'active',
    });
  }

  Future<void> enrollSimulatedFingerprint({
    required String beneficiaryId,
    required String tenantId,
  }) async {
    await _client.from('biometric_enrollments').insert({
      'beneficiary_id': beneficiaryId,
      'tenant_id': tenantId,
      'biometric_type': 'fingerprint',
      'provider': 'simulated_secugen_ready',
      'template_id': 'sim_fp_${DateTime.now().millisecondsSinceEpoch}',
      'template_data': 'simulated_fingerprint_template',
      'quality_score': 92,
      'status': 'active',
    });
  }
}
