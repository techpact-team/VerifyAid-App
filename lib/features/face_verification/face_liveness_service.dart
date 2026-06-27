class FaceLivenessResult {
  const FaceLivenessResult({
    required this.configured,
    required this.passed,
    required this.message,
    this.metadata = const {},
  });

  final bool configured;
  final bool? passed;
  final String message;
  final Map<String, dynamic> metadata;

  static const notConfigured = FaceLivenessResult(
    configured: false,
    passed: null,
    message: 'Liveness check is not configured for this build',
    metadata: {
      'liveness_provider': 'not_configured',
      'liveness_required': false,
    },
  );
}

class FaceLivenessService {
  const FaceLivenessService();

  Future<FaceLivenessResult> evaluateStillImage({
    required String imagePath,
  }) async {
    return FaceLivenessResult.notConfigured;
  }
}
