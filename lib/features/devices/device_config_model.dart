class DeviceConfig {
  final String? id;
  final String tenantId;
  final String? locationId;
  final String? configuredBy;

  final String deviceName;
  final String connectionType; // usb or bluetooth
  final String secugenModel;

  final String? deviceSerial;
  final String? vendorId;
  final String? productId;
  final String? bluetoothMacAddress;

  final String templateFormat;
  final int qualityThreshold;
  final int matchThreshold;
  final bool livenessEnabled;
  final bool isActive;

  final Map<String, dynamic> metadata;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeviceConfig({
    this.id,
    required this.tenantId,
    this.locationId,
    this.configuredBy,
    required this.deviceName,
    required this.connectionType,
    required this.secugenModel,
    this.deviceSerial,
    this.vendorId,
    this.productId,
    this.bluetoothMacAddress,
    this.templateFormat = 'secugen_400',
    this.qualityThreshold = 70,
    this.matchThreshold = 80,
    this.livenessEnabled = false,
    this.isActive = true,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      locationId: json['location_id'] as String?,
      configuredBy: json['configured_by'] as String?,
      deviceName: json['device_name'] as String? ?? 'SecuGen Device',
      connectionType: json['connection_type'] as String? ?? 'usb',
      secugenModel: json['secugen_model'] as String? ?? 'Hamster Pro 20 USB',
      deviceSerial: json['device_serial'] as String?,
      vendorId: json['vendor_id'] as String?,
      productId: json['product_id'] as String?,
      bluetoothMacAddress: json['bluetooth_mac_address'] as String?,
      templateFormat: json['template_format'] as String? ?? 'secugen_400',
      qualityThreshold: json['quality_threshold'] as int? ?? 70,
      matchThreshold: json['match_threshold'] as int? ?? 80,
      livenessEnabled: json['liveness_enabled'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at']),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'tenant_id': tenantId,
      'location_id': locationId,
      'configured_by': configuredBy,
      'device_name': deviceName,
      'connection_type': connectionType,
      'secugen_model': secugenModel,
      'device_serial': deviceSerial,
      'vendor_id': vendorId,
      'product_id': productId,
      'bluetooth_mac_address': bluetoothMacAddress,
      'template_format': templateFormat,
      'quality_threshold': qualityThreshold,
      'match_threshold': matchThreshold,
      'liveness_enabled': livenessEnabled,
      'is_active': isActive,
      'metadata': metadata,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'location_id': locationId,
      'device_name': deviceName,
      'connection_type': connectionType,
      'secugen_model': secugenModel,
      'device_serial': deviceSerial,
      'vendor_id': vendorId,
      'product_id': productId,
      'bluetooth_mac_address': bluetoothMacAddress,
      'template_format': templateFormat,
      'quality_threshold': qualityThreshold,
      'match_threshold': matchThreshold,
      'liveness_enabled': livenessEnabled,
      'is_active': isActive,
      'metadata': metadata,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  DeviceConfig copyWith({
    String? id,
    String? tenantId,
    String? locationId,
    String? configuredBy,
    String? deviceName,
    String? connectionType,
    String? secugenModel,
    String? deviceSerial,
    String? vendorId,
    String? productId,
    String? bluetoothMacAddress,
    String? templateFormat,
    int? qualityThreshold,
    int? matchThreshold,
    bool? livenessEnabled,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceConfig(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      locationId: locationId ?? this.locationId,
      configuredBy: configuredBy ?? this.configuredBy,
      deviceName: deviceName ?? this.deviceName,
      connectionType: connectionType ?? this.connectionType,
      secugenModel: secugenModel ?? this.secugenModel,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      bluetoothMacAddress: bluetoothMacAddress ?? this.bluetoothMacAddress,
      templateFormat: templateFormat ?? this.templateFormat,
      qualityThreshold: qualityThreshold ?? this.qualityThreshold,
      matchThreshold: matchThreshold ?? this.matchThreshold,
      livenessEnabled: livenessEnabled ?? this.livenessEnabled,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
