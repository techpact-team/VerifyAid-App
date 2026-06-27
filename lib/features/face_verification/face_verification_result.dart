enum FaceVerificationStatus {
  matched,
  failed,
  uncertain,
  noFaceDetected,
  multipleFacesDetected,
  poorQuality,
  livenessFailed,
  noRegisteredFace,
  engineUnavailable,
  error,
}

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.status,
    required this.message,
    this.matchScore,
    this.threshold,
    this.qualityScore,
    this.livenessPassed,
    this.registeredFacePath,
    this.liveFaceLocalPath,
    this.liveFaceStoragePath,
    this.metadata = const {},
  });

  final FaceVerificationStatus status;
  final double? matchScore;
  final double? threshold;
  final double? qualityScore;
  final bool? livenessPassed;
  final String message;
  final String? registeredFacePath;
  final String? liveFaceLocalPath;
  final String? liveFaceStoragePath;
  final Map<String, dynamic> metadata;

  bool get isMatched => status == FaceVerificationStatus.matched;

  bool get isBlockingFailure {
    return switch (status) {
      FaceVerificationStatus.matched => false,
      FaceVerificationStatus.engineUnavailable => false,
      _ => true,
    };
  }

  String get statusLabel {
    return switch (status) {
      FaceVerificationStatus.matched => 'Matched',
      FaceVerificationStatus.failed => 'Failed',
      FaceVerificationStatus.uncertain => 'Uncertain',
      FaceVerificationStatus.noFaceDetected => 'No face detected',
      FaceVerificationStatus.multipleFacesDetected => 'Multiple faces',
      FaceVerificationStatus.poorQuality => 'Poor quality',
      FaceVerificationStatus.livenessFailed => 'Liveness failed',
      FaceVerificationStatus.noRegisteredFace => 'No registered face',
      FaceVerificationStatus.engineUnavailable => 'Recognition unavailable',
      FaceVerificationStatus.error => 'Error',
    };
  }

  Map<String, dynamic> toAuditMetadata() {
    return {
      'source': 'flutter_mobile',
      'flow': 'distribution_face_verification',
      'status': status.name,
      'message': message,
      'match_score': matchScore,
      'threshold': threshold,
      'quality_score': qualityScore,
      'liveness_passed': livenessPassed,
      'registered_face_path': registeredFacePath,
      'live_face_local_path': liveFaceLocalPath,
      'live_face_storage_path': liveFaceStoragePath,
      ...metadata,
    };
  }
}
