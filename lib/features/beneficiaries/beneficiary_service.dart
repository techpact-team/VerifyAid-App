import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../core/network/connectivity_service.dart';
import '../../core/storage/local_storage.dart' as app_storage;
import 'beneficiary_draft.dart';

class BeneficiaryService {
  final supabase = Supabase.instance.client;
  final connectivity = ConnectivityService();
  final localStorage = app_storage.LocalStorage();

  Future<String?> registerBeneficiary(BeneficiaryDraft draft) async {
    final online = await connectivity.hasInternet();

    if (!online) {
      await localStorage.savePendingBeneficiary(draft.toJson());
      return null;
    }

    final response = await supabase
        .from('beneficiaries')
        .insert(draft.toJson())
        .select('id')
        .single();

    return response['id'] as String;
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

  Future<void> saveBeneficiaryPhotoPath({
    required String beneficiaryId,
    required String photoPath,
  }) async {
    await supabase
        .from('beneficiaries')
        .update({'photo_url': photoPath})
        .eq('id', beneficiaryId);
  }
}
