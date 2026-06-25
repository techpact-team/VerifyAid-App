enum FaceQualityStatus {
  noFaceDetected,
  multipleFacesDetected,
  faceTooFar,
  faceOffCenter,
  tooDark,
  tooBright,
  tooBlurry,
  accepted,
}

class FaceQualityResult {
  const FaceQualityResult({
    required this.status,
    required this.message,
    this.qualityScore,
  });

  final FaceQualityStatus status;
  final String message;
  final double? qualityScore;

  bool get isAccepted => status == FaceQualityStatus.accepted;

  static const noFaceDetected = FaceQualityResult(
    status: FaceQualityStatus.noFaceDetected,
    message: 'No face detected',
  );

  static const multipleFacesDetected = FaceQualityResult(
    status: FaceQualityStatus.multipleFacesDetected,
    message: 'Multiple faces detected',
  );

  static const faceTooFar = FaceQualityResult(
    status: FaceQualityStatus.faceTooFar,
    message: 'Face too far',
  );

  static const faceOffCenter = FaceQualityResult(
    status: FaceQualityStatus.faceOffCenter,
    message: 'Face not centered',
  );

  static const tooDark = FaceQualityResult(
    status: FaceQualityStatus.tooDark,
    message: 'Face image is too dark',
  );

  static const tooBright = FaceQualityResult(
    status: FaceQualityStatus.tooBright,
    message: 'Face image is too bright',
  );

  static const tooBlurry = FaceQualityResult(
    status: FaceQualityStatus.tooBlurry,
    message: 'Face image is too blurry',
  );

  static FaceQualityResult accepted({double? qualityScore}) {
    return FaceQualityResult(
      status: FaceQualityStatus.accepted,
      message: 'Face captured successfully',
      qualityScore: qualityScore,
    );
  }
}
