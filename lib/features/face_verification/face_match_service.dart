import 'dart:math';

import 'face_verification_result.dart';

class FaceMatchResult {
  const FaceMatchResult({
    required this.status,
    required this.message,
    this.matchScore,
    this.threshold,
    this.metadata = const {},
  });

  final FaceVerificationStatus status;
  final String message;
  final double? matchScore;
  final double? threshold;
  final Map<String, dynamic> metadata;
}

abstract class FaceEmbeddingEngine {
  bool get isConfigured;

  String get algorithmName;

  String get modelVersion;

  Future<List<double>?> createEmbedding(String imagePath);
}

class UnavailableFaceEmbeddingEngine implements FaceEmbeddingEngine {
  const UnavailableFaceEmbeddingEngine();

  @override
  bool get isConfigured => false;

  @override
  String get algorithmName => 'not_configured';

  @override
  String get modelVersion => 'none';

  @override
  Future<List<double>?> createEmbedding(String imagePath) async {
    return null;
  }
}

class FaceMatchService {
  const FaceMatchService({
    this.engine = const UnavailableFaceEmbeddingEngine(),
    this.threshold = 0.82,
  });

  final FaceEmbeddingEngine engine;
  final double threshold;

  bool get isConfigured => engine.isConfigured;

  String get algorithmName => engine.algorithmName;

  String get modelVersion => engine.modelVersion;

  Future<FaceMatchResult> compareFaces({
    required String registeredFacePath,
    required String liveFacePath,
  }) async {
    if (!engine.isConfigured) {
      return FaceMatchResult(
        status: FaceVerificationStatus.engineUnavailable,
        message:
            'Face recognition engine is not configured. Use manual fallback only.',
        threshold: threshold,
        metadata: {
          'algorithm': algorithmName,
          'model_version': modelVersion,
          'recognition_provider': 'not_configured',
        },
      );
    }

    final registeredEmbedding = await engine.createEmbedding(
      registeredFacePath,
    );
    final liveEmbedding = await engine.createEmbedding(liveFacePath);

    if (registeredEmbedding == null || liveEmbedding == null) {
      return FaceMatchResult(
        status: FaceVerificationStatus.error,
        message: 'Face embedding could not be created',
        threshold: threshold,
        metadata: {'algorithm': algorithmName, 'model_version': modelVersion},
      );
    }

    if (registeredEmbedding.length != liveEmbedding.length ||
        registeredEmbedding.isEmpty) {
      return FaceMatchResult(
        status: FaceVerificationStatus.error,
        message: 'Face embedding dimensions are invalid',
        threshold: threshold,
        metadata: {
          'algorithm': algorithmName,
          'model_version': modelVersion,
          'registered_embedding_length': registeredEmbedding.length,
          'live_embedding_length': liveEmbedding.length,
        },
      );
    }

    final score = _cosineSimilarity(registeredEmbedding, liveEmbedding);
    final status = score >= threshold
        ? FaceVerificationStatus.matched
        : FaceVerificationStatus.failed;

    return FaceMatchResult(
      status: status,
      message: status == FaceVerificationStatus.matched
          ? 'Face recognition matched'
          : 'Face recognition failed',
      matchScore: score,
      threshold: threshold,
      metadata: {
        'algorithm': algorithmName,
        'model_version': modelVersion,
        'similarity_metric': 'cosine_similarity',
      },
    );
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}
