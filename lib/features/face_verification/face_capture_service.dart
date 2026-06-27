import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'face_quality_service.dart';

class FaceCaptureResult {
  const FaceCaptureResult({
    required this.file,
    required this.quality,
    required this.persisted,
  });

  final File file;
  final FaceQualityAssessment quality;
  final bool persisted;

  bool get isAccepted => quality.accepted;
}

class FaceCaptureService {
  FaceCaptureService({
    ImagePicker? imagePicker,
    FaceQualityService? qualityService,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _qualityService = qualityService ?? const FaceQualityService();

  final ImagePicker _imagePicker;
  final FaceQualityService _qualityService;
  final Uuid _uuid = const Uuid();

  Future<FaceCaptureResult?> captureValidatedFace({
    ImageSource source = ImageSource.camera,
  }) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile == null) return null;

    final quality = await _qualityService.validateImage(pickedFile.path);
    final file = quality.accepted
        ? await _copyToAppStorage(File(pickedFile.path))
        : File(pickedFile.path);

    return FaceCaptureResult(
      file: file,
      quality: quality,
      persisted: quality.accepted,
    );
  }

  Future<File> _copyToAppStorage(File sourceFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final faceDirectory = Directory(
      p.join(directory.path, 'face_verification_scans'),
    );

    if (!faceDirectory.existsSync()) {
      await faceDirectory.create(recursive: true);
    }

    final extension = p.extension(sourceFile.path).isEmpty
        ? '.jpg'
        : p.extension(sourceFile.path);
    final targetPath = p.join(faceDirectory.path, '${_uuid.v4()}$extension');

    return sourceFile.copy(targetPath);
  }
}
