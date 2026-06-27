import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_config_model.dart';
import 'secugen_device_service.dart';

class SecugenUsbService implements SecugenDeviceService {
  static const MethodChannel _channel = MethodChannel('verifyaid/secugen_usb');

  @override
  Future<SecugenDeviceInfo> testConnection(DeviceConfig config) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('testUsbConnection', {
            'vendorId': config.vendorId,
            'productId': config.productId,
            'model': config.secugenModel,
          });

      return SecugenDeviceInfo.fromJson(
        Map<String, dynamic>.from(result ?? {}),
      );
    } on MissingPluginException catch (e) {
      debugPrint('SecuGen USB bridge missing: $e');
      return SecugenDeviceInfo.failure(
        'SecuGen USB native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen USB test error: $e');
      return SecugenDeviceInfo.failure('USB connection test failed.');
    }
  }

  @override
  Future<SecugenCaptureResult> captureFingerprint(DeviceConfig config) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('captureFingerprint', {
            'connectionType': 'usb',
            'qualityThreshold': config.qualityThreshold,
            'templateFormat': config.templateFormat,
            'livenessEnabled': config.livenessEnabled,
            'model': config.secugenModel,
          });

      return SecugenCaptureResult.fromJson(
        Map<String, dynamic>.from(result ?? {}),
      );
    } on MissingPluginException catch (e) {
      debugPrint('SecuGen USB bridge missing: $e');
      return SecugenCaptureResult.failure(
        'SecuGen USB native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen USB capture error: $e');
      return SecugenCaptureResult.failure('Fingerprint capture failed.');
    }
  }

  @override
  Future<SecugenMatchResult> matchFingerprint({
    required DeviceConfig config,
    required String registeredTemplate,
    required String liveTemplate,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('matchFingerprint', {
            'connectionType': 'usb',
            'registeredTemplate': registeredTemplate,
            'liveTemplate': liveTemplate,
            'threshold': config.matchThreshold,
            'templateFormat': config.templateFormat,
            'model': config.secugenModel,
          });

      return SecugenMatchResult.fromJson(
        Map<String, dynamic>.from(result ?? {}),
      );
    } on MissingPluginException catch (e) {
      debugPrint('SecuGen USB bridge missing: $e');
      return SecugenMatchResult.failure(
        'SecuGen USB native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen USB match error: $e');
      return SecugenMatchResult.failure('Fingerprint matching failed.');
    }
  }
}
