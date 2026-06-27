import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_config_model.dart';
import 'secugen_device_service.dart';

class SecugenBluetoothService implements SecugenDeviceService {
  static const MethodChannel _channel = MethodChannel(
    'verifyaid/secugen_bluetooth',
  );

  @override
  Future<SecugenDeviceInfo> testConnection(DeviceConfig config) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('testBluetoothConnection', {
            'bluetoothMacAddress': config.bluetoothMacAddress,
            'model': config.secugenModel,
          });

      return SecugenDeviceInfo.fromJson(
        Map<String, dynamic>.from(result ?? {}),
      );
    } on MissingPluginException catch (e) {
      debugPrint('SecuGen Bluetooth bridge missing: $e');
      return SecugenDeviceInfo.failure(
        'SecuGen Bluetooth native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen Bluetooth test error: $e');
      return SecugenDeviceInfo.failure('Bluetooth connection test failed.');
    }
  }

  @override
  Future<SecugenCaptureResult> captureFingerprint(DeviceConfig config) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('captureFingerprint', {
            'connectionType': 'bluetooth',
            'bluetoothMacAddress': config.bluetoothMacAddress,
            'qualityThreshold': config.qualityThreshold,
            'templateFormat': config.templateFormat,
            'livenessEnabled': config.livenessEnabled,
            'model': config.secugenModel,
          });

      return SecugenCaptureResult.fromJson(
        Map<String, dynamic>.from(result ?? {}),
      );
    } on MissingPluginException catch (e) {
      debugPrint('SecuGen Bluetooth bridge missing: $e');
      return SecugenCaptureResult.failure(
        'SecuGen Bluetooth native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen Bluetooth capture error: $e');
      return SecugenCaptureResult.failure(
        'Bluetooth fingerprint capture failed.',
      );
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
            'connectionType': 'bluetooth',
            'bluetoothMacAddress': config.bluetoothMacAddress,
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
      debugPrint('SecuGen Bluetooth bridge missing: $e');
      return SecugenMatchResult.failure(
        'SecuGen Bluetooth native bridge is not configured yet.',
      );
    } catch (e) {
      debugPrint('SecuGen Bluetooth match error: $e');
      return SecugenMatchResult.failure(
        'Bluetooth fingerprint matching failed.',
      );
    }
  }
}
