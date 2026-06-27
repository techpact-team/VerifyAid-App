import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../core/database/local_beneficiary_repository.dart';
import '../../core/database/local_distribution_repository.dart';
import '../../core/database/local_questionnaire_repository.dart';
import '../../core/database/local_sync_queue.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/storage/local_storage.dart';
import '../../services/biometric_service.dart';
import '../beneficiaries/beneficiary_service.dart';
import '../questionnaires/questionnaire_service.dart';
import 'sync_result.dart';

class SyncQueueProcessor {
  SyncQueueProcessor({
    LocalBeneficiaryRepository? beneficiaryRepository,
    LocalQuestionnaireRepository? questionnaireRepository,
    LocalDistributionRepository? distributionRepository,
    LocalSyncQueue? syncQueue,
    BeneficiaryService? beneficiaryService,
    QuestionnaireService? questionnaireService,
    BiometricService? biometricService,
  }) : _beneficiaries = beneficiaryRepository ?? LocalBeneficiaryRepository(),
       _questionnaires =
           questionnaireRepository ?? LocalQuestionnaireRepository(),
       _distributions = distributionRepository ?? LocalDistributionRepository(),
       _syncQueue = syncQueue ?? LocalSyncQueue(),
       _beneficiaryService = beneficiaryService ?? BeneficiaryService(),
       _questionnaireService = questionnaireService ?? QuestionnaireService(),
       _biometricService = biometricService ?? BiometricService();

  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalBeneficiaryRepository _beneficiaries;
  final LocalQuestionnaireRepository _questionnaires;
  final LocalDistributionRepository _distributions;
  final LocalSyncQueue _syncQueue;
  final BeneficiaryService _beneficiaryService;
  final QuestionnaireService _questionnaireService;
  final BiometricService _biometricService;

  Future<SyncResult> process() async {
    final startedAt = DateTime.now();
    final messages = <String>[];
    var successCount = 0;
    var failedCount = 0;
    var skippedCount = 0;

    await LocalStorage().migrateLegacyPendingBeneficiaries();

    if (!await ConnectivityService.hasInternetConnection()) {
      await _syncQueue.log(
        entityType: 'sync',
        operation: 'process',
        status: 'skipped',
        message: 'Device is offline.',
      );

      return SyncResult(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        successCount: 0,
        failedCount: 0,
        skippedCount: 0,
        messages: const ['Device is offline.'],
      );
    }

    await _syncQueue.resetInterruptedSyncs();

    for (final record in await _beneficiaries.recordsForSync(limit: 50)) {
      try {
        await _syncBeneficiary(record);
        successCount += 1;
      } catch (error) {
        failedCount += 1;
        messages.add('Beneficiary ${record.localId}: $error');
      }
    }

    for (final record in await _questionnaires.recordsForSync(limit: 50)) {
      try {
        final synced = await _syncQuestionnaireResponse(record);
        if (synced) {
          successCount += 1;
        } else {
          skippedCount += 1;
        }
      } catch (error) {
        failedCount += 1;
        messages.add('Questionnaire ${record.localId}: $error');
      }
    }

    for (final record in await _distributions.recordsForSync(limit: 50)) {
      try {
        final synced = await _syncDistribution(record);
        if (synced) {
          successCount += 1;
        } else {
          skippedCount += 1;
        }
      } catch (error) {
        failedCount += 1;
        messages.add('Distribution ${record.localId}: $error');
      }
    }

    return SyncResult(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      successCount: successCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      messages: messages,
    );
  }

  Future<void> _syncBeneficiary(PendingBeneficiaryRecord record) async {
    await _beneficiaries.markSyncing(record.localId);
    await _syncQueue.log(
      entityType: 'beneficiary',
      localId: record.localId,
      operation: 'sync',
      status: 'syncing',
      message: 'Syncing beneficiary.',
    );

    try {
      final remoteId = record.remoteId ?? await _insertBeneficiary(record);

      final photoPath = await _uploadBeneficiaryPhotoIfNeeded(
        record: record,
        remoteId: remoteId,
      );
      final facePhotoPath = await _uploadFacePhotoIfNeeded(
        record: record,
        remoteId: remoteId,
      );

      await _beneficiaries.markSynced(
        localId: record.localId,
        remoteId: remoteId,
        photoPath: photoPath,
        facePhotoPath: facePhotoPath,
      );
      await _questionnaires.updateRemoteBeneficiaryId(
        localBeneficiaryId: record.localId,
        remoteBeneficiaryId: remoteId,
      );
      await _distributions.updateRemoteBeneficiaryId(
        localBeneficiaryId: record.localId,
        remoteBeneficiaryId: remoteId,
      );

      await _syncQueue.log(
        entityType: 'beneficiary',
        localId: record.localId,
        operation: 'sync',
        status: 'synced',
        message: 'Beneficiary synced.',
      );
    } catch (error) {
      await _beneficiaries.markFailed(
        localId: record.localId,
        error: error.toString(),
      );
      await _syncQueue.log(
        entityType: 'beneficiary',
        localId: record.localId,
        operation: 'sync',
        status: 'failed',
        message: error.toString(),
      );
      rethrow;
    }
  }

  Future<String> _insertBeneficiary(PendingBeneficiaryRecord record) async {
    final payload = Map<String, dynamic>.from(record.payload);
    payload['id'] = record.localId;

    try {
      final response = await _supabase
          .from('beneficiaries')
          .insert(payload)
          .select('id')
          .single();

      return response['id'] as String;
    } on PostgrestException catch (error) {
      if (!_isDuplicateError(error)) {
        rethrow;
      }

      final existingById = await _supabase
          .from('beneficiaries')
          .select('id')
          .eq('id', record.localId)
          .maybeSingle();

      if (existingById != null) {
        return existingById['id'] as String;
      }

      final nationalId = payload['national_id']?.toString().trim();
      if (nationalId != null && nationalId.isNotEmpty) {
        final existingByNationalId = await _supabase
            .from('beneficiaries')
            .select('id')
            .eq('tenant_id', record.tenantId)
            .eq('national_id', nationalId)
            .maybeSingle();

        if (existingByNationalId != null) {
          return existingByNationalId['id'] as String;
        }
      }

      rethrow;
    }
  }

  Future<String?> _uploadBeneficiaryPhotoIfNeeded({
    required PendingBeneficiaryRecord record,
    required String remoteId,
  }) async {
    final localPath = record.photoLocalPath;
    if (localPath == null || localPath.isEmpty) {
      return null;
    }

    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Local beneficiary photo is missing: $localPath');
    }

    final photoPath = await _beneficiaryService.uploadBeneficiaryPhoto(
      photoFile: file,
      tenantId: record.tenantId,
      beneficiaryId: remoteId,
    );

    await _beneficiaryService.saveBeneficiaryPhotoPath(
      beneficiaryId: remoteId,
      photoPath: photoPath,
    );

    return photoPath;
  }

  Future<String?> _uploadFacePhotoIfNeeded({
    required PendingBeneficiaryRecord record,
    required String remoteId,
  }) async {
    final localPath = record.facePhotoLocalPath;
    if (localPath == null || localPath.isEmpty) {
      return null;
    }

    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Local face photo is missing: $localPath');
    }

    final facePhotoPath = await _beneficiaryService.uploadBeneficiaryFacePhoto(
      photoFile: file,
      tenantId: record.tenantId,
      beneficiaryId: remoteId,
    );

    try {
      await _biometricService.enrollFacePhoto(
        beneficiaryId: remoteId,
        tenantId: record.tenantId,
        photoUrl: facePhotoPath,
      );
    } on PostgrestException catch (error) {
      if (!_isDuplicateError(error)) {
        rethrow;
      }
    }

    return facePhotoPath;
  }

  Future<bool> _syncQuestionnaireResponse(
    PendingQuestionnaireResponseRecord record,
  ) async {
    final remoteBeneficiaryId =
        record.remoteBeneficiaryId ??
        (await _beneficiaries.findByLocalId(
          record.localBeneficiaryId,
        ))?.remoteId;

    if (remoteBeneficiaryId == null || remoteBeneficiaryId.isEmpty) {
      await _syncQueue.log(
        entityType: 'questionnaire_response',
        localId: record.localId,
        operation: 'sync',
        status: 'skipped',
        message: 'Waiting for beneficiary sync.',
      );
      return false;
    }

    await _questionnaires.markSyncing(record.localId);

    try {
      final responseId = await _insertQuestionnaireResponse(
        record: record,
        remoteBeneficiaryId: remoteBeneficiaryId,
      );

      await _questionnaires.markSynced(
        localId: record.localId,
        remoteResponseId: responseId,
      );
      await _syncQueue.log(
        entityType: 'questionnaire_response',
        localId: record.localId,
        operation: 'sync',
        status: 'synced',
        message: 'Questionnaire response synced.',
      );
      return true;
    } catch (error) {
      await _questionnaires.markFailed(
        localId: record.localId,
        error: error.toString(),
      );
      await _syncQueue.log(
        entityType: 'questionnaire_response',
        localId: record.localId,
        operation: 'sync',
        status: 'failed',
        message: error.toString(),
      );
      rethrow;
    }
  }

  Future<String> _insertQuestionnaireResponse({
    required PendingQuestionnaireResponseRecord record,
    required String remoteBeneficiaryId,
  }) async {
    try {
      return await _questionnaireService.saveQuestionnaireResponse(
        tenantId: record.tenantId,
        questionnaireId: record.questionnaireId,
        programId: record.programId,
        beneficiaryId: remoteBeneficiaryId,
        submittedBy: record.submittedBy,
        answers: record.answers,
        responseId: record.localId,
      );
    } on PostgrestException catch (error) {
      if (!_isDuplicateError(error)) {
        rethrow;
      }

      final existing = await _supabase
          .from('questionnaire_responses')
          .select('id')
          .eq('id', record.localId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      rethrow;
    }
  }

  Future<bool> _syncDistribution(PendingDistributionRecord record) async {
    final remoteBeneficiaryId =
        record.beneficiaryId ??
        (record.localBeneficiaryId == null
            ? null
            : (await _beneficiaries.findByLocalId(
                record.localBeneficiaryId!,
              ))?.remoteId);

    if (remoteBeneficiaryId == null || remoteBeneficiaryId.isEmpty) {
      await _syncQueue.log(
        entityType: 'distribution_event',
        localId: record.localId,
        operation: 'sync',
        status: 'skipped',
        message: 'Waiting for beneficiary sync.',
      );
      return false;
    }

    await _distributions.markSyncing(record.localId);

    try {
      final remoteId = await _insertDistribution(
        record: record,
        remoteBeneficiaryId: remoteBeneficiaryId,
      );

      await _distributions.markSynced(
        localId: record.localId,
        remoteId: remoteId,
      );
      await _syncQueue.log(
        entityType: 'distribution_event',
        localId: record.localId,
        operation: 'sync',
        status: 'synced',
        message: 'Distribution event synced.',
      );
      return true;
    } catch (error) {
      await _distributions.markFailed(
        localId: record.localId,
        error: error.toString(),
      );
      await _syncQueue.log(
        entityType: 'distribution_event',
        localId: record.localId,
        operation: 'sync',
        status: 'failed',
        message: error.toString(),
      );
      rethrow;
    }
  }

  Future<String> _insertDistribution({
    required PendingDistributionRecord record,
    required String remoteBeneficiaryId,
  }) async {
    final payload = Map<String, dynamic>.from(record.payload);
    payload['id'] = record.localId;
    payload['tenant_id'] = record.tenantId;
    payload['beneficiary_id'] = remoteBeneficiaryId;
    payload['program_id'] = record.programId;
    payload['distributed_by'] = record.distributedBy;

    try {
      final response = await _supabase
          .from('distribution_events')
          .insert(payload)
          .select('id')
          .single();

      return response['id'] as String;
    } on PostgrestException catch (error) {
      if (!_isDuplicateError(error)) {
        rethrow;
      }

      final existing = await _supabase
          .from('distribution_events')
          .select('id')
          .eq('id', record.localId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      rethrow;
    }
  }

  bool _isDuplicateError(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase();

    return code == '23505' ||
        message.contains('duplicate key') ||
        message.contains('already exists');
  }
}
