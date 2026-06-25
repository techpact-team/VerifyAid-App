import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../core/database/local_beneficiary_repository.dart';
import '../../core/network/connectivity_service.dart';
import 'beneficiary_draft.dart';

class BeneficiaryService {
  final supabase = Supabase.instance.client;
  final localBeneficiaries = LocalBeneficiaryRepository();

  Future<String?> registerBeneficiary(BeneficiaryDraft draft) async {
    final result = await saveBeneficiary(draft: draft);
    return result.remoteId;
  }

  Future<BeneficiarySaveResult> saveBeneficiary({
    required BeneficiaryDraft draft,
    String? photoLocalPath,
    String? facePhotoLocalPath,
  }) async {
    final payload = draft.toJson();
    final online = await ConnectivityService.hasInternetConnection();

    if (!online) {
      final localId = await _saveLocal(
        payload: payload,
        draft: draft,
        photoLocalPath: photoLocalPath,
        facePhotoLocalPath: facePhotoLocalPath,
      );

      return BeneficiarySaveResult.savedLocally(localId: localId);
    }

    try {
      final response = await supabase
          .from('beneficiaries')
          .insert(payload)
          .select('id')
          .single();

      return BeneficiarySaveResult.synced(remoteId: response['id'] as String);
    } on PostgrestException {
      rethrow;
    } catch (error) {
      if (!_isLikelyNetworkError(error)) {
        rethrow;
      }

      final localId = await _saveLocal(
        payload: payload,
        draft: draft,
        photoLocalPath: photoLocalPath,
        facePhotoLocalPath: facePhotoLocalPath,
      );

      return BeneficiarySaveResult.savedLocally(
        localId: localId,
        message: 'Network failed. Saved locally.',
      );
    }
  }

  Future<String> uploadBeneficiaryPhoto({
    required File photoFile,
    required String tenantId,
    required String beneficiaryId,
  }) async {
    final fileExt = photoFile.path.split('.').last;
    final filePath =
        '$tenantId/beneficiaries/$beneficiaryId/profile-photo.$fileExt';

    await supabase.storage
        .from('beneficiary-photos')
        .upload(
          filePath,
          photoFile,
          fileOptions: const FileOptions(upsert: true),
        );

    return filePath;
  }

  Future<String> uploadBeneficiaryFacePhoto({
    required File photoFile,
    required String tenantId,
    required String beneficiaryId,
  }) async {
    final fileExt = photoFile.path.split('.').last;
    final filePath =
        '$tenantId/beneficiaries/$beneficiaryId/face-photo.$fileExt';

    await supabase.storage
        .from('beneficiary-photos')
        .upload(
          filePath,
          photoFile,
          fileOptions: const FileOptions(upsert: true),
        );

    return filePath;
  }

  Future<void> saveBeneficiaryPhotoPath({
    required String beneficiaryId,
    required String photoPath,
  }) async {
    await supabase
        .from('beneficiaries')
        .update({'photo_url': photoPath})
        .eq('id', beneficiaryId);
  }

  Future<String> _saveLocal({
    required Map<String, dynamic> payload,
    required BeneficiaryDraft draft,
    String? photoLocalPath,
    String? facePhotoLocalPath,
  }) {
    return localBeneficiaries.savePendingBeneficiary(
      payload: payload,
      tenantId: draft.tenantId,
      programId: draft.programId,
      locationId: draft.locationId,
      createdBy: draft.createdBy,
      photoLocalPath: photoLocalPath,
      facePhotoLocalPath: facePhotoLocalPath,
    );
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

class BeneficiarySaveResult {
  const BeneficiarySaveResult({
    required this.savedLocally,
    this.remoteId,
    this.localId,
    required this.message,
  });

  final bool savedLocally;
  final String? remoteId;
  final String? localId;
  final String message;

  bool get synced => !savedLocally && remoteId != null;

  factory BeneficiarySaveResult.synced({required String remoteId}) {
    return BeneficiarySaveResult(
      savedLocally: false,
      remoteId: remoteId,
      message: 'Synced',
    );
  }

  factory BeneficiarySaveResult.savedLocally({
    required String localId,
    String message = 'Saved locally',
  }) {
    return BeneficiarySaveResult(
      savedLocally: true,
      localId: localId,
      message: message,
    );
  }
}
