import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> enrollSimulatedFingerprint({
    required String beneficiaryId,
    required String tenantId,
  }) async {
    await supabase.from('biometric_enrollments').insert({
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

  Future<void> enrollFacePhoto({
    required String beneficiaryId,
    required String tenantId,
    required String photoPath,
  }) async {
    await supabase.from('biometric_enrollments').insert({
      'beneficiary_id': beneficiaryId,
      'tenant_id': tenantId,
      'biometric_type': 'face',
      'provider': 'camera_photo',
      'template_id': 'face_${DateTime.now().millisecondsSinceEpoch}',
      'template_data': photoPath,
      'quality_score': 85,
      'status': 'active',
    });
  }

  Future<bool> hasActiveFingerprint(String beneficiaryId) async {
    final row = await supabase
        .from('biometric_enrollments')
        .select('id')
        .eq('beneficiary_id', beneficiaryId)
        .eq('biometric_type', 'fingerprint')
        .eq('status', 'active')
        .maybeSingle();

    return row != null;
  }

  Future<String?> getFacePhotoPath(String beneficiaryId) async {
    final row = await supabase
        .from('biometric_enrollments')
        .select('template_data')
        .eq('beneficiary_id', beneficiaryId)
        .eq('biometric_type', 'face')
        .eq('status', 'active')
        .maybeSingle();

    return row?['template_data'] as String?;
  }

  Future<String?> getSignedFacePhotoUrl(String beneficiaryId) async {
    final photoPath = await getFacePhotoPath(beneficiaryId);

    if (photoPath == null) return null;

    return await supabase.storage
        .from('beneficiary-photos')
        .createSignedUrl(photoPath, 60 * 10);
  }

  Future<bool> verifySimulatedFingerprint(String beneficiaryId) async {
    return await hasActiveFingerprint(beneficiaryId);
  }
}
