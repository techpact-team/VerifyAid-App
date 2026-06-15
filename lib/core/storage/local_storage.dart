import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const pendingBeneficiariesKey = 'pending_beneficiaries';

  Future<void> savePendingBeneficiary(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getStringList(pendingBeneficiariesKey) ?? [];

    existing.add(jsonEncode(data));

    await prefs.setStringList(pendingBeneficiariesKey, existing);
  }

  Future<List<Map<String, dynamic>>> getPendingBeneficiaries() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getStringList(pendingBeneficiariesKey) ?? [];

    return existing
        .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
        .toList();
  }

  Future<void> clearPendingBeneficiaries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingBeneficiariesKey);
  }
}
