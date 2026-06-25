import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'face_enrollment_result.dart';
import 'face_quality_result.dart';

class FaceScanService {
  FaceScanService({ImagePicker? imagePicker}) {
    _imagePicker = imagePicker ?? ImagePicker();
  }

  late final ImagePicker _imagePicker;
  final Uuid _uuid = const Uuid();

  Future<FaceEnrollmentResult?> captureAndValidateFace() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile == null) return null;

    final quality = await validateFaceImage(pickedFile.path);
    if (!quality.isAccepted) {
      return FaceEnrollmentResult(quality: quality);
    }

    final storedPath = await _storeFacePhoto(File(pickedFile.path));
    return FaceEnrollmentResult(quality: quality, localImagePath: storedPath);
  }

  Future<FaceQualityResult> validateFaceImage(String imagePath) async {
    final sourceFile = File(imagePath);
    if (!sourceFile.existsSync()) {
      return FaceQualityResult.noFaceDetected;
    }

    final imageBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return FaceQualityResult.tooBlurry;
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
        return FaceQualityResult.noFaceDetected;
      }

      if (faces.length > 1) {
        return FaceQualityResult.multipleFacesDetected;
      }

      final face = faces.first;
      final sizeResult = _checkFaceSize(face, orientedImage);
      if (!sizeResult.isAccepted) {
        return sizeResult;
      }

      final centerResult = _checkFaceCenter(face, orientedImage);
      if (!centerResult.isAccepted) {
        return centerResult;
      }

      final faceImage = _cropFace(orientedImage, face);
      final brightness = _averageBrightness(faceImage);
      if (brightness < 45) {
        return FaceQualityResult.tooDark;
      }
      if (brightness > 225) {
        return FaceQualityResult.tooBright;
      }

      final sharpness = _laplacianVariance(faceImage);
      if (sharpness < 14) {
        return FaceQualityResult.tooBlurry;
      }

      return FaceQualityResult.accepted(
        qualityScore: _qualityScore(
          face: face,
          image: orientedImage,
          brightness: brightness,
          sharpness: sharpness,
        ),
      );
    } finally {
      await detector.close();
    }
  }

  FaceQualityResult _checkFaceSize(Face face, img.Image image) {
    final rect = face.boundingBox;
    final widthRatio = rect.width / image.width;
    final heightRatio = rect.height / image.height;

    if (widthRatio < 0.22 || heightRatio < 0.22) {
      return FaceQualityResult.faceTooFar;
    }

    return FaceQualityResult.accepted();
  }

  FaceQualityResult _checkFaceCenter(Face face, img.Image image) {
    final rect = face.boundingBox;
    final faceCenterX = rect.left + (rect.width / 2);
    final faceCenterY = rect.top + (rect.height / 2);
    final imageCenterX = image.width / 2;
    final imageCenterY = image.height / 2;

    final normalizedXOffset = (faceCenterX - imageCenterX).abs() / image.width;
    final normalizedYOffset = (faceCenterY - imageCenterY).abs() / image.height;

    if (normalizedXOffset > 0.22 || normalizedYOffset > 0.24) {
      return FaceQualityResult.faceOffCenter;
    }

    return FaceQualityResult.accepted();
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

  Future<String> _storeFacePhoto(File sourceFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final faceDirectory = Directory(p.join(directory.path, 'face_scans'));

    if (!faceDirectory.existsSync()) {
      await faceDirectory.create(recursive: true);
    }

    final extension = p.extension(sourceFile.path).isEmpty
        ? '.jpg'
        : p.extension(sourceFile.path);
    final targetPath = p.join(faceDirectory.path, '${_uuid.v4()}$extension');

    final storedFile = await sourceFile.copy(targetPath);
    return storedFile.path;
  }
}
