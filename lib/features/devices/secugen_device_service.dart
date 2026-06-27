import 'device_config_model.dart';
import 'secugen_bluetooth_service.dart';
import 'secugen_usb_service.dart';

class SecugenDeviceInfo {
  final bool connected;
  final String message;
  final String? deviceSerial;
  final String? model;
  final Map<String, dynamic> metadata;

  const SecugenDeviceInfo({
    required this.connected,
    required this.message,
    this.deviceSerial,
    this.model,
    this.metadata = const {},
  });

  factory SecugenDeviceInfo.fromJson(Map<String, dynamic> json) {
    return SecugenDeviceInfo(
      connected: json['connected'] == true || json['success'] == true,
      message: json['message'] as String? ?? 'No message returned',
      deviceSerial: json['deviceSerial'] as String?,
      model: json['model'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  factory SecugenDeviceInfo.failure(String message) {
    return SecugenDeviceInfo(connected: false, message: message);
  }
}

class SecugenCaptureResult {
  final bool success;
  final String message;
  final int? qualityScore;
  final String? template;
  final String? templateFormat;
  final String? deviceSerial;
  final Map<String, dynamic> metadata;

  const SecugenCaptureResult({
    required this.success,
    required this.message,
    this.qualityScore,
    this.template,
    this.templateFormat,
    this.deviceSerial,
    this.metadata = const {},
  });

  factory SecugenCaptureResult.fromJson(Map<String, dynamic> json) {
    return SecugenCaptureResult(
      success: json['success'] == true,
      message: json['message'] as String? ?? 'No message returned',
      qualityScore: json['qualityScore'] as int?,
      template: json['template'] as String?,
      templateFormat: json['templateFormat'] as String?,
      deviceSerial: json['deviceSerial'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  factory SecugenCaptureResult.failure(String message) {
    return SecugenCaptureResult(success: false, message: message);
  }
}

class SecugenMatchResult {
  final bool matched;
  final String message;
  final num? matchScore;
  final num? threshold;
  final Map<String, dynamic> metadata;

  const SecugenMatchResult({
    required this.matched,
    required this.message,
    this.matchScore,
    this.threshold,
    this.metadata = const {},
  });

  factory SecugenMatchResult.fromJson(Map<String, dynamic> json) {
    return SecugenMatchResult(
      matched: json['matched'] == true,
      message: json['message'] as String? ?? 'No message returned',
      matchScore: json['matchScore'] as num?,
      threshold: json['threshold'] as num?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  factory SecugenMatchResult.failure(String message) {
    return SecugenMatchResult(matched: false, message: message);
  }
}

abstract class SecugenDeviceService {
  Future<SecugenDeviceInfo> testConnection(DeviceConfig config);

  Future<SecugenCaptureResult> captureFingerprint(DeviceConfig config);

  Future<SecugenMatchResult> matchFingerprint({
    required DeviceConfig config,
    required String registeredTemplate,
    required String liveTemplate,
  });

  static SecugenDeviceService fromConfig(DeviceConfig config) {
    if (config.connectionType == 'bluetooth') {
      return SecugenBluetoothService();
    }

    return SecugenUsbService();
  }
}
