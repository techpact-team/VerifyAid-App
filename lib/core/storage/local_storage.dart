import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/local_beneficiary_repository.dart';

class LocalStorage {
  static const pendingBeneficiariesKey = 'pending_beneficiaries';

  final LocalBeneficiaryRepository _beneficiaryRepository =
      LocalBeneficiaryRepository();

  Future<void> savePendingBeneficiary(Map<String, dynamic> data) async {
    await migrateLegacyPendingBeneficiaries();

    await _beneficiaryRepository.savePendingBeneficiary(
      payload: data,
      tenantId: data['tenant_id']?.toString() ?? '',
      programId: data['program_id']?.toString() ?? '',
      locationId: data['location_id']?.toString() ?? '',
      createdBy: data['created_by']?.toString() ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingBeneficiaries() async {
    await migrateLegacyPendingBeneficiaries();

    final records = await _beneficiaryRepository.recordsForSync(limit: 1000);
    return records.map((record) => record.payload).toList();
  }

  Future<void> clearPendingBeneficiaries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingBeneficiariesKey);
  }

  Future<void> migrateLegacyPendingBeneficiaries() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(pendingBeneficiariesKey) ?? [];

    if (existing.isEmpty) return;

    for (final item in existing) {
      final data = Map<String, dynamic>.from(jsonDecode(item) as Map);

      await _beneficiaryRepository.savePendingBeneficiary(
        payload: data,
        tenantId: data['tenant_id']?.toString() ?? '',
        programId: data['program_id']?.toString() ?? '',
        locationId: data['location_id']?.toString() ?? '',
        createdBy: data['created_by']?.toString() ?? '',
      );
    }

    await prefs.remove(pendingBeneficiariesKey);
  }
}
