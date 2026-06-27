import 'face_quality_result.dart';

class FaceEnrollmentResult {
  const FaceEnrollmentResult({required this.quality, this.localImagePath});

  final FaceQualityResult quality;
  final String? localImagePath;

  bool get isSuccess => quality.isAccepted && localImagePath != null;
}
