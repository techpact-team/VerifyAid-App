import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'device_config_model.dart';
import 'device_config_service.dart';
import 'secugen_device_service.dart';

class DeviceConfigScreen extends StatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen> {
  final service = DeviceConfigService();

  final deviceNameController = TextEditingController();
  final deviceSerialController = TextEditingController();
  final vendorIdController = TextEditingController();
  final productIdController = TextEditingController();
  final bluetoothMacController = TextEditingController();
  final qualityThresholdController = TextEditingController(text: '70');
  final matchThresholdController = TextEditingController(text: '80');

  DeviceConfig? currentConfig;

  String connectionType = 'usb';
  String secugenModel = 'Hamster Pro 20 USB';
  String templateFormat = 'secugen_400';
  bool livenessEnabled = false;

  bool loading = true;
  bool saving = false;
  bool testing = false;
  String? error;
  String? testMessage;
  bool? testSuccess;

  final List<String> connectionTypes = const ['usb', 'bluetooth'];

  final List<String> secugenModels = const [
    'Hamster Pro 20 USB',
    'Hamster Pro V2 USB',
    'Hamster Air USB',
    'Unity 20 Bluetooth',
    'Other SecuGen Device',
  ];

  final List<String> templateFormats = const [
    'secugen_400',
    'iso_19794_2',
    'ansi_378',
  ];

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  @override
  void dispose() {
    deviceNameController.dispose();
    deviceSerialController.dispose();
    vendorIdController.dispose();
    productIdController.dispose();
    bluetoothMacController.dispose();
    qualityThresholdController.dispose();
    matchThresholdController.dispose();
    super.dispose();
  }

  Future<void> loadConfig() async {
    try {
      final activeConfig = await service.getActiveDeviceConfig();

      if (!mounted) return;

      if (activeConfig != null) {
        applyConfigToForm(activeConfig);

        setState(() {
          currentConfig = activeConfig;
          loading = false;
        });

        return;
      }

      final defaultConfig = await service.buildDefaultConfigFromProfile();
      applyConfigToForm(defaultConfig);

      setState(() {
        currentConfig = defaultConfig;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void applyConfigToForm(DeviceConfig config) {
    deviceNameController.text = config.deviceName;
    deviceSerialController.text = config.deviceSerial ?? '';
    vendorIdController.text = config.vendorId ?? '';
    productIdController.text = config.productId ?? '';
    bluetoothMacController.text = config.bluetoothMacAddress ?? '';
    qualityThresholdController.text = config.qualityThreshold.toString();
    matchThresholdController.text = config.matchThreshold.toString();

    connectionType = config.connectionType;
    secugenModel = config.secugenModel;
    templateFormat = config.templateFormat;
    livenessEnabled = config.livenessEnabled;
  }

  DeviceConfig buildConfigFromForm() {
    final base = currentConfig;

    if (base == null) {
      throw Exception('Device profile is not ready.');
    }

    return base.copyWith(
      deviceName: deviceNameController.text.trim(),
      connectionType: connectionType,
      secugenModel: secugenModel,
      deviceSerial: emptyToNull(deviceSerialController.text),
      vendorId: emptyToNull(vendorIdController.text),
      productId: emptyToNull(productIdController.text),
      bluetoothMacAddress: emptyToNull(bluetoothMacController.text),
      templateFormat: templateFormat,
      qualityThreshold:
          int.tryParse(qualityThresholdController.text.trim()) ?? 70,
      matchThreshold: int.tryParse(matchThresholdController.text.trim()) ?? 80,
      livenessEnabled: livenessEnabled,
      isActive: true,
      metadata: {
        ...base.metadata,
        'configured_from': 'device_config_screen',
        'updated_from_mobile_at': DateTime.now().toIso8601String(),
      },
    );
  }

  String? emptyToNull(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  Future<void> testConnection() async {
    setState(() {
      testing = true;
      testMessage = null;
      testSuccess = null;
    });

    try {
      final config = buildConfigFromForm();
      final secugenService = SecugenDeviceService.fromConfig(config);

      final result = await secugenService.testConnection(config);

      if (!mounted) return;

      setState(() {
        testSuccess = result.connected;
        testMessage = result.message;
        testing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        testSuccess = false;
        testMessage = e.toString();
        testing = false;
      });
    }
  }

  Future<void> saveConfig() async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      final config = buildConfigFromForm();
      final saved = await service.saveAsActive(config);

      if (!mounted) return;

      setState(() {
        currentConfig = saved;
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device configuration saved')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save configuration')),
      );
    }
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null && currentConfig == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          title: const Text('Device Configuration'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load device configuration:\n\n$error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final isBluetooth = connectionType == 'bluetooth';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Device Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'SecuGen Fingerprint Scanner',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Configure the fingerprint scanner used for beneficiary enrollment and distribution verification.',
          ),

          const SizedBox(height: 24),

          buildTextField(
            controller: deviceNameController,
            label: 'Device Name',
            hint: 'Example: SecuGen Scanner 1',
          ),

          buildDropdown(
            label: 'Connection Type',
            value: connectionType,
            options: connectionTypes,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                connectionType = value;

                if (value == 'bluetooth' &&
                    secugenModel == 'Hamster Pro 20 USB') {
                  secugenModel = 'Unity 20 Bluetooth';
                }

                if (value == 'usb' && secugenModel == 'Unity 20 Bluetooth') {
                  secugenModel = 'Hamster Pro 20 USB';
                }
              });
            },
          ),

          buildDropdown(
            label: 'SecuGen Model',
            value: secugenModel,
            options: secugenModels,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                secugenModel = value;
              });
            },
          ),

          buildTextField(
            controller: deviceSerialController,
            label: 'Device Serial Number',
            hint: 'Optional',
          ),

          if (!isBluetooth) ...[
            buildTextField(
              controller: vendorIdController,
              label: 'USB Vendor ID',
              hint: 'Optional',
            ),
            buildTextField(
              controller: productIdController,
              label: 'USB Product ID',
              hint: 'Optional',
            ),
          ],

          if (isBluetooth)
            buildTextField(
              controller: bluetoothMacController,
              label: 'Bluetooth MAC Address',
              hint: 'Example: 00:11:22:33:44:55',
            ),

          buildDropdown(
            label: 'Template Format',
            value: templateFormat,
            options: templateFormats,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                templateFormat = value;
              });
            },
          ),

          buildTextField(
            controller: qualityThresholdController,
            label: 'Quality Threshold',
            keyboardType: TextInputType.number,
          ),

          buildTextField(
            controller: matchThresholdController,
            label: 'Match Threshold',
            keyboardType: TextInputType.number,
          ),

          SwitchListTile(
            value: livenessEnabled,
            title: const Text('Enable Fake Finger / Liveness Check'),
            subtitle: const Text(
              'Only enable this if your SecuGen device and SDK support it.',
            ),
            onChanged: (value) {
              setState(() {
                livenessEnabled = value;
              });
            },
          ),

          const SizedBox(height: 16),

          if (testMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: testSuccess == true
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                testMessage!,
                style: TextStyle(
                  color: testSuccess == true
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: testing ? null : testConnection,
              icon: const Icon(Icons.usb),
              label: Text(testing ? 'Testing...' : 'Test Connection'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : saveConfig,
              icon: const Icon(Icons.save),
              label: Text(saving ? 'Saving...' : 'Save Configuration'),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Note: This screen saves the scanner configuration. Actual fingerprint capture requires the native Android SecuGen SDK bridge to be connected.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
