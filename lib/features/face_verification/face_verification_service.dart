import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'face_capture_service.dart';
import 'face_liveness_service.dart';
import 'face_match_service.dart';
import 'face_verification_result.dart';

class FaceVerificationService {
  FaceVerificationService({
    SupabaseClient? client,
    FaceCaptureService? captureService,
    FaceLivenessService? livenessService,
    FaceMatchService? matchService,
  }) : _client = client ?? Supabase.instance.client,
       _captureService = captureService ?? FaceCaptureService(),
       _livenessService = livenessService ?? const FaceLivenessService(),
       _matchService = matchService ?? const FaceMatchService();

  static const storageBucket = 'beneficiary-photos';

  final SupabaseClient _client;
  final FaceCaptureService _captureService;
  final FaceLivenessService _livenessService;
  final FaceMatchService _matchService;

  Future<String?> getRegisteredFacePath({
    required String beneficiaryId,
    Map<String, dynamic>? beneficiary,
  }) async {
    try {
      final response = await _client
          .from('biometric_enrollments')
          .select('template_data')
          .eq('beneficiary_id', beneficiaryId)
          .eq('biometric_type', 'face')
          .eq('status', 'active')
          .limit(1);

      final rows = List<Map<String, dynamic>>.from(response);
      final path = rows.isEmpty ? null : rows.first['template_data'];
      final cleanPath = path?.toString().trim();

      if (cleanPath != null && cleanPath.isNotEmpty) {
        return cleanPath;
      }
    } catch (error) {
      debugPrint('Registered face lookup failed: $error');
    }

    final fallback = beneficiary?['face_photo_url']?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return null;
  }

  Future<String?> getSignedFaceUrl(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    if (_isUrl(storagePath)) return storagePath;

    try {
      return await _client.storage
          .from(storageBucket)
          .createSignedUrl(storagePath, 60 * 10);
    } catch (error) {
      debugPrint('Signed face URL failed: $error');
      return null;
    }
  }

  Future<FaceVerificationResult?> scanAndVerify({
    required Map<String, dynamic> beneficiary,
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
  }) async {
    final registeredFacePath = await getRegisteredFacePath(
      beneficiaryId: beneficiaryId,
      beneficiary: beneficiary,
    );

    if (registeredFacePath == null || registeredFacePath.isEmpty) {
      final result = FaceVerificationResult(
        status: FaceVerificationStatus.noRegisteredFace,
        message: 'No registered face enrollment found for this beneficiary',
        metadata: _baseMetadata,
      );

      await recordAttempt(
        result: result,
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
      );

      return result;
    }

    final capture = await _captureService.captureValidatedFace();
    if (capture == null) return null;

    if (!capture.quality.accepted) {
      final result = FaceVerificationResult(
        status: capture.quality.status,
        message: capture.quality.message,
        qualityScore: capture.quality.qualityScore,
        registeredFacePath: registeredFacePath,
        liveFaceLocalPath: capture.file.path,
        metadata: {..._baseMetadata, 'quality': capture.quality.metadata},
      );

      await recordAttempt(
        result: result,
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
      );

      return result;
    }

    final liveness = await _livenessService.evaluateStillImage(
      imagePath: capture.file.path,
    );

    if (liveness.configured && liveness.passed == false) {
      final result = FaceVerificationResult(
        status: FaceVerificationStatus.livenessFailed,
        message: liveness.message,
        qualityScore: capture.quality.qualityScore,
        livenessPassed: liveness.passed,
        registeredFacePath: registeredFacePath,
        liveFaceLocalPath: capture.file.path,
        metadata: {
          ..._baseMetadata,
          'quality': capture.quality.metadata,
          'liveness': liveness.metadata,
        },
      );

      await recordAttempt(
        result: result,
        tenantId: tenantId,
        programId: programId,
        beneficiaryId: beneficiaryId,
        locationId: locationId,
      );

      return result;
    }

    var liveStoragePath = '';
    Map<String, dynamic> uploadMetadata = const {};
    try {
      liveStoragePath = await uploadLiveFaceAttempt(
        tenantId: tenantId,
        beneficiaryId: beneficiaryId,
        liveFaceFile: capture.file,
      );
    } catch (error) {
      debugPrint('Live face upload failed: $error');
      uploadMetadata = {'live_face_upload_error': error.toString()};
    }

    final registeredMatchPath = _matchService.isConfigured
        ? await _downloadRegisteredFaceForMatching(registeredFacePath)
        : registeredFacePath;

    final match = await _matchService.compareFaces(
      registeredFacePath: registeredMatchPath,
      liveFacePath: capture.file.path,
    );

    final result = FaceVerificationResult(
      status: match.status,
      message: match.message,
      matchScore: match.matchScore,
      threshold: match.threshold,
      qualityScore: capture.quality.qualityScore,
      livenessPassed: liveness.passed,
      registeredFacePath: registeredFacePath,
      liveFaceLocalPath: capture.file.path,
      liveFaceStoragePath: liveStoragePath.isEmpty ? null : liveStoragePath,
      metadata: {
        ..._baseMetadata,
        ...uploadMetadata,
        'quality': capture.quality.metadata,
        'liveness': liveness.metadata,
        ...match.metadata,
      },
    );

    await recordAttempt(
      result: result,
      tenantId: tenantId,
      programId: programId,
      beneficiaryId: beneficiaryId,
      locationId: locationId,
    );

    return result;
  }

  Future<String> uploadLiveFaceAttempt({
    required String tenantId,
    required String beneficiaryId,
    required File liveFaceFile,
  }) async {
    final extension = p.extension(liveFaceFile.path).isEmpty
        ? '.jpg'
        : p.extension(liveFaceFile.path);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final storagePath =
        '$tenantId/distribution-verifications/$beneficiaryId/'
        '$timestamp-live-face$extension';

    await _client.storage
        .from(storageBucket)
        .upload(
          storagePath,
          liveFaceFile,
          fileOptions: const FileOptions(upsert: false),
        );

    return storagePath;
  }

  Future<void> recordAttempt({
    required FaceVerificationResult result,
    required String tenantId,
    required String programId,
    required String beneficiaryId,
    required String locationId,
    String? distributionEventId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('Face verification audit skipped: no authenticated user.');
      return;
    }

    final payload = {
      'tenant_id': tenantId,
      'program_id': programId,
      'beneficiary_id': beneficiaryId,
      'distribution_event_id': distributionEventId,
      'verified_by': user.id,
      'location_id': locationId,
      'registered_face_path': result.registeredFacePath,
      'live_face_path': result.liveFaceStoragePath ?? result.liveFaceLocalPath,
      'status': result.status.name,
      'match_score': result.matchScore,
      'threshold': result.threshold,
      'quality_score': result.qualityScore,
      'liveness_passed': result.livenessPassed,
      'algorithm': result.metadata['algorithm'] ?? 'not_configured',
      'model_version': result.metadata['model_version'] ?? 'none',
      'failure_reason': result.isMatched ? null : result.message,
      'metadata': result.toAuditMetadata(),
    };

    try {
      await _client.from('face_verification_attempts').insert(payload);
    } on PostgrestException catch (error) {
      debugPrint(
        'Face verification audit insert skipped: '
        '${error.code ?? 'unknown'} ${error.message}',
      );
    } catch (error) {
      debugPrint('Face verification audit insert failed: $error');
    }
  }

  Future<String> _downloadRegisteredFaceForMatching(String storagePath) async {
    if (_isUrl(storagePath) || File(storagePath).existsSync()) {
      return storagePath;
    }

    final bytes = await _client.storage
        .from(storageBucket)
        .download(storagePath);
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory(
      p.join(directory.path, 'registered_face_cache'),
    );

    if (!cacheDirectory.existsSync()) {
      await cacheDirectory.create(recursive: true);
    }

    final extension = p.extension(storagePath).isEmpty
        ? '.jpg'
        : p.extension(storagePath);
    final file = File(
      p.join(
        cacheDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  bool _isUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Map<String, dynamic> get _baseMetadata {
    return {
      'source': 'flutter_mobile',
      'flow': 'distribution_face_verification',
      'recognition_policy': _matchService.isConfigured
          ? 'face_recognition_required'
          : 'manual_fallback_required',
    };
  }
}
