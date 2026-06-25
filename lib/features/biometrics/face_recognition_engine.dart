class FaceRecognitionCandidate {
  const FaceRecognitionCandidate({
    required this.beneficiaryId,
    required this.confidence,
  });

  final String beneficiaryId;
  final double confidence;
}

abstract class FaceRecognitionEngine {
  Future<List<double>?> createEmbedding(String imagePath);

  Future<FaceRecognitionCandidate?> match({
    required String imagePath,
    required List<FaceRecognitionCandidate> candidates,
  });
}

class UnavailableFaceRecognitionEngine implements FaceRecognitionEngine {
  const UnavailableFaceRecognitionEngine();

  @override
  Future<List<double>?> createEmbedding(String imagePath) async {
    return null;
  }

  @override
  Future<FaceRecognitionCandidate?> match({
    required String imagePath,
    required List<FaceRecognitionCandidate> candidates,
  }) async {
    return null;
  }
}
