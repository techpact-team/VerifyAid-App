import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_verification_result.dart';

class FaceQualityAssessment {
  const FaceQualityAssessment({
    required this.accepted,
    required this.status,
    required this.message,
    this.qualityScore,
    this.metadata = const {},
  });

  final bool accepted;
  final FaceVerificationStatus status;
  final String message;
  final double? qualityScore;
  final Map<String, dynamic> metadata;

  bool get isAccepted => accepted;

  factory FaceQualityAssessment.accepted({
    required double qualityScore,
    required Map<String, dynamic> metadata,
  }) {
    return FaceQualityAssessment(
      accepted: true,
      status: FaceVerificationStatus.uncertain,
      message: 'Face quality accepted',
      qualityScore: qualityScore,
      metadata: metadata,
    );
  }

  factory FaceQualityAssessment.rejected({
    required FaceVerificationStatus status,
    required String message,
    Map<String, dynamic> metadata = const {},
  }) {
    return FaceQualityAssessment(
      accepted: false,
      status: status,
      message: message,
      metadata: metadata,
    );
  }
}

class FaceQualityService {
  const FaceQualityService();

  Future<FaceQualityAssessment> validateImage(String imagePath) async {
    final sourceFile = File(imagePath);
    if (!sourceFile.existsSync()) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.error,
        message: 'Face image file was not found',
      );
    }

    final imageBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.poorQuality,
        message: 'Face image could not be read',
      );
    }

    final orientedImage = img.bakeOrientation(decoded);
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
        minFaceSize: 0.16,
      ),
    );

    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(imagePath),
      );

      if (faces.isEmpty) {
        return FaceQualityAssessment.rejected(
          status: FaceVerificationStatus.noFaceDetected,
          message: 'No face detected',
          metadata: {'face_count': 0},
        );
      }

      if (faces.length > 1) {
        return FaceQualityAssessment.rejected(
          status: FaceVerificationStatus.multipleFacesDetected,
          message: 'Multiple faces detected',
          metadata: {'face_count': faces.length},
        );
      }

      final face = faces.first;
      final baseMetadata = _faceMetadata(face, orientedImage);

      final sizeResult = _checkFaceSize(face, orientedImage, baseMetadata);
      if (sizeResult != null) {
        return sizeResult;
      }

      final centerResult = _checkFaceCenter(face, orientedImage, baseMetadata);
      if (centerResult != null) {
        return centerResult;
      }

      final angleResult = _checkHeadAngles(face, baseMetadata);
      if (angleResult != null) {
        return angleResult;
      }

      final eyeResult = _checkEyes(face, baseMetadata);
      if (eyeResult != null) {
        return eyeResult;
      }

      final faceImage = _cropFace(orientedImage, face);
      final brightness = _averageBrightness(faceImage);
      final brightnessMetadata = {...baseMetadata, 'brightness': brightness};

      if (brightness < 45) {
        return FaceQualityAssessment.rejected(
          status: FaceVerificationStatus.poorQuality,
          message: 'Face image is too dark',
          metadata: brightnessMetadata,
        );
      }
      if (brightness > 225) {
        return FaceQualityAssessment.rejected(
          status: FaceVerificationStatus.poorQuality,
          message: 'Face image is too bright',
          metadata: brightnessMetadata,
        );
      }

      final sharpness = _laplacianVariance(faceImage);
      final metadata = {...brightnessMetadata, 'sharpness': sharpness};

      if (sharpness < 14) {
        return FaceQualityAssessment.rejected(
          status: FaceVerificationStatus.poorQuality,
          message: 'Face image is too blurry',
          metadata: metadata,
        );
      }

      final qualityScore = _qualityScore(
        face: face,
        image: orientedImage,
        brightness: brightness,
        sharpness: sharpness,
      );

      return FaceQualityAssessment.accepted(
        qualityScore: qualityScore,
        metadata: {
          ...metadata,
          'quality_provider': 'google_mlkit_face_detection',
          'quality_algorithm': 'mlkit_detection_brightness_laplacian_v1',
        },
      );
    } catch (error) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.error,
        message: 'Face quality check failed',
        metadata: {'error': error.toString()},
      );
    } finally {
      await detector.close();
    }
  }

  FaceQualityAssessment? _checkFaceSize(
    Face face,
    img.Image image,
    Map<String, dynamic> metadata,
  ) {
    final rect = face.boundingBox;
    final widthRatio = rect.width / image.width;
    final heightRatio = rect.height / image.height;

    if (widthRatio < 0.22 || heightRatio < 0.22) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.poorQuality,
        message: 'Move closer so the face fills the frame',
        metadata: metadata,
      );
    }

    return null;
  }

  FaceQualityAssessment? _checkFaceCenter(
    Face face,
    img.Image image,
    Map<String, dynamic> metadata,
  ) {
    final rect = face.boundingBox;
    final faceCenterX = rect.left + (rect.width / 2);
    final faceCenterY = rect.top + (rect.height / 2);
    final imageCenterX = image.width / 2;
    final imageCenterY = image.height / 2;

    final normalizedXOffset = (faceCenterX - imageCenterX).abs() / image.width;
    final normalizedYOffset = (faceCenterY - imageCenterY).abs() / image.height;

    if (normalizedXOffset > 0.22 || normalizedYOffset > 0.24) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.poorQuality,
        message: 'Center the face in the frame',
        metadata: {
          ...metadata,
          'center_x_offset': normalizedXOffset,
          'center_y_offset': normalizedYOffset,
        },
      );
    }

    return null;
  }

  FaceQualityAssessment? _checkHeadAngles(
    Face face,
    Map<String, dynamic> metadata,
  ) {
    final angleX = face.headEulerAngleX;
    final angleY = face.headEulerAngleY;
    final angleZ = face.headEulerAngleZ;

    if ((angleX != null && angleX.abs() > 22) ||
        (angleY != null && angleY.abs() > 25) ||
        (angleZ != null && angleZ.abs() > 18)) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.poorQuality,
        message: 'Face the camera directly',
        metadata: metadata,
      );
    }

    return null;
  }

  FaceQualityAssessment? _checkEyes(Face face, Map<String, dynamic> metadata) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if ((leftEye != null && leftEye < 0.25) ||
        (rightEye != null && rightEye < 0.25)) {
      return FaceQualityAssessment.rejected(
        status: FaceVerificationStatus.poorQuality,
        message: 'Keep both eyes open',
        metadata: metadata,
      );
    }

    return null;
  }

  Map<String, dynamic> _faceMetadata(Face face, img.Image image) {
    final rect = face.boundingBox;
    return {
      'face_count': 1,
      'image_width': image.width,
      'image_height': image.height,
      'bounding_box': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
        'width': rect.width,
        'height': rect.height,
      },
      'face_width_ratio': rect.width / image.width,
      'face_height_ratio': rect.height / image.height,
      'head_euler_x': face.headEulerAngleX,
      'head_euler_y': face.headEulerAngleY,
      'head_euler_z': face.headEulerAngleZ,
      'left_eye_open_probability': face.leftEyeOpenProbability,
      'right_eye_open_probability': face.rightEyeOpenProbability,
    };
  }

  img.Image _cropFace(img.Image image, Face face) {
    final rect = face.boundingBox;
    final padding = max(rect.width, rect.height) * 0.18;
    final left = max(0, rect.left - padding).round();
    final top = max(0, rect.top - padding).round();
    final right = min(image.width, rect.right + padding).round();
    final bottom = min(image.height, rect.bottom + padding).round();
    final width = max(1, right - left);
    final height = max(1, bottom - top);

    return img.copyCrop(image, x: left, y: top, width: width, height: height);
  }

  double _averageBrightness(img.Image image) {
    final step = max(1, sqrt((image.width * image.height) / 5000).round());
    var total = 0.0;
    var count = 0;

    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        total += _luminance(image.getPixel(x, y));
        count += 1;
      }
    }

    if (count == 0) return 0;
    return total / count;
  }

  double _laplacianVariance(img.Image image) {
    final resized = image.width > 180
        ? img.copyResize(image, width: 180)
        : image;

    if (resized.width < 3 || resized.height < 3) {
      return 0;
    }

    var count = 0;
    var sum = 0.0;
    var sumSquares = 0.0;

    for (var y = 1; y < resized.height - 1; y += 2) {
      for (var x = 1; x < resized.width - 1; x += 2) {
        final center = _luminance(resized.getPixel(x, y));
        final laplacian =
            (_luminance(resized.getPixel(x - 1, y)) +
                _luminance(resized.getPixel(x + 1, y)) +
                _luminance(resized.getPixel(x, y - 1)) +
                _luminance(resized.getPixel(x, y + 1))) -
            (4 * center);

        sum += laplacian;
        sumSquares += laplacian * laplacian;
        count += 1;
      }
    }

    if (count == 0) return 0;

    final mean = sum / count;
    return (sumSquares / count) - (mean * mean);
  }

  double _luminance(img.Pixel pixel) {
    return (0.2126 * pixel.r) + (0.7152 * pixel.g) + (0.0722 * pixel.b);
  }

  double _qualityScore({
    required Face face,
    required img.Image image,
    required double brightness,
    required double sharpness,
  }) {
    final rect = face.boundingBox;
    final faceSizeScore = min(
      rect.width / image.width,
      rect.height / image.height,
    );
    final brightnessScore = 1 - ((brightness - 135).abs() / 135).clamp(0, 1);
    final sharpnessScore = (sharpness / 120).clamp(0, 1);
    final score =
        (faceSizeScore.clamp(0, 1) * 35) +
        (brightnessScore * 30) +
        (sharpnessScore * 35);

    return score.clamp(0, 100).toDouble();
  }
}
