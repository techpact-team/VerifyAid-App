import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricRepository {
  final supabase = Supabase.instance.client;

  Future<void> saveBiometric({
    required String beneficiaryId,
    required String templateId,
    required String provider,
    required String type,
    required int qualityScore,
  }) async {
    await supabase.from('biometric_enrollments').insert({
      'beneficiary_id': beneficiaryId,
      'template_id': templateId,
      'provider': provider,
      'type': type,
      'quality_score': qualityScore,
      'status': 'active',
    });
  }
}
