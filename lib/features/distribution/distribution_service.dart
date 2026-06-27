import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/local_distribution_repository.dart';
import '../../core/network/connectivity_service.dart';

class DistributionService {
  final supabase = Supabase.instance.client;
  final localDistributions = LocalDistributionRepository();

  Future<List<Map<String, dynamic>>> searchBeneficiaries({
    required String query,
    required String tenantId,
    required String locationId,
  }) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) return [];

    final response = await supabase
        .from('beneficiaries')
        .select()
        .eq('tenant_id', tenantId)
        .eq('location_id', locationId)
        .or(
          'full_name.ilike.%$cleanQuery%,phone.ilike.%$cleanQuery%,national_id.ilike.%$cleanQuery%',
        )
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch a single beneficiary by ID, validated against tenant.
  /// Used by QR code lookup flow.
  Future<Map<String, dynamic>?> fetchBeneficiaryById({
    required String beneficiaryId,
    required String tenantId,
  }) async {
    final response = await supabase
        .from('beneficiaries')
        .select()
        .eq('id', beneficiaryId)
        .eq('tenant_id', tenantId)
        .maybeSingle();

    return response;
  }

  /// Resolve a beneficiary's photo_url into a viewable signed URL.
  /// Returns null if no photo is available.
  Future<String?> getSignedPhotoUrl(String? photoUrl) async {
    if (photoUrl == null || photoUrl.trim().isEmpty) return null;

    // Already a full URL — return as-is.
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return photoUrl;
    }

    // Storage path — generate a signed URL.
    try {
      return await supabase.storage
          .from('beneficiary-photos')
          .createSignedUrl(photoUrl, 60 * 10);
    } catch (e) {
      debugPrint('Failed to sign photo URL: $e');
      return null;
    }
  }

  Future<bool> hasReceivedAidAlready({
    required String beneficiaryId,
    required String programId,
  }) async {
    final response = await supabase
        .from('distribution_events')
        .select('id')
        .eq('beneficiary_id', beneficiaryId)
        .eq('program_id', programId)
        .eq('status', 'completed')
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.isNotEmpty;
  }

  Future<String> recordDistributionSuccess({
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
    required String itemName,
    required num quantity,
    required String verificationMethod,
    String verificationStatus = 'matched',
    Map<String, dynamic>? metadata,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final payload = {
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
      'verification_status': verificationStatus,
      'metadata':
          metadata ??
          {'source': 'flutter_mobile', 'flow': 'distribution_verification'},
    };

    return _insertOrQueueDistribution(
      payload: payload,
      tenantId: tenantId,
      programId: programId,
      beneficiaryId: beneficiaryId,
      distributedBy: user.id,
    );
  }

  Future<String> recordDistributionRejected({
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
    required String reason,
    required String verificationMethod,
    String verificationStatus = 'failed',
    Map<String, dynamic>? metadata,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final payload = {
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
      'verification_status': verificationStatus,
      'rejection_reason': reason,
      'metadata':
          metadata ??
          {'source': 'flutter_mobile', 'flow': 'distribution_verification'},
    };

    return _insertOrQueueDistribution(
      payload: payload,
      tenantId: tenantId,
      programId: programId,
      beneficiaryId: beneficiaryId,
      distributedBy: user.id,
    );
  }

  Future<String> _insertOrQueueDistribution({
    required Map<String, dynamic> payload,
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String distributedBy,
  }) async {
    debugPrint('Distribution payload: $payload');

    if (!await ConnectivityService.hasInternetConnection()) {
      return localDistributions.savePendingDistribution(
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        distributedBy: distributedBy,
        payload: payload,
      );
    }

    try {
      final response = await supabase
          .from('distribution_events')
          .insert(payload)
          .select('id')
          .single();

      return response['id'] as String;
    } on PostgrestException {
      rethrow;
    } catch (error) {
      if (!_isLikelyNetworkError(error)) {
        rethrow;
      }

      return localDistributions.savePendingDistribution(
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        distributedBy: distributedBy,
        payload: payload,
      );
    }
  }

  bool _isLikelyNetworkError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('offline') ||
        message.contains('failed host lookup') ||
        message.contains('internet');
  }
}
