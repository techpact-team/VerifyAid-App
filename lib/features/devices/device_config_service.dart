import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_config_model.dart';

class DeviceConfigService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('id, tenant_id, location_id, full_name, email, status')
        .eq('id', user.id)
        .maybeSingle();

    return profile;
  }

  Future<List<DeviceConfig>> getDeviceConfigs() async {
    final profile = await getCurrentProfile();

    if (profile == null) {
      throw Exception('No profile found for current user.');
    }

    final tenantId = profile['tenant_id'];

    final response = await supabase
        .from('device_configurations')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      response,
    ).map(DeviceConfig.fromJson).toList();
  }

  Future<DeviceConfig?> getActiveDeviceConfig() async {
    final profile = await getCurrentProfile();

    if (profile == null) {
      throw Exception('No profile found for current user.');
    }

    final tenantId = profile['tenant_id'];
    final locationId = profile['location_id'];

    var query = supabase
        .from('device_configurations')
        .select()
        .eq('tenant_id', tenantId)
        .eq('is_active', true);

    if (locationId != null) {
      query = query.eq('location_id', locationId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    return DeviceConfig.fromJson(response);
  }

  Future<DeviceConfig> saveDeviceConfig(DeviceConfig config) async {
    if (config.id == null) {
      final response = await supabase
          .from('device_configurations')
          .insert(config.toCreateJson())
          .select()
          .single();

      return DeviceConfig.fromJson(response);
    }

    final response = await supabase
        .from('device_configurations')
        .update(config.toUpdateJson())
        .eq('id', config.id!)
        .select()
        .single();

    return DeviceConfig.fromJson(response);
  }

  Future<void> deactivateOtherConfigs({
    required String tenantId,
    String? locationId,
  }) async {
    try {
      var query = supabase
          .from('device_configurations')
          .update({'is_active': false})
          .eq('tenant_id', tenantId);

      if (locationId != null) {
        query = query.eq('location_id', locationId);
      }

      await query;
    } catch (e) {
      debugPrint('Failed to deactivate old device configs: $e');
    }
  }

  Future<DeviceConfig> saveAsActive(DeviceConfig config) async {
    await deactivateOtherConfigs(
      tenantId: config.tenantId,
      locationId: config.locationId,
    );

    return saveDeviceConfig(config.copyWith(isActive: true));
  }

  Future<DeviceConfig> buildDefaultConfigFromProfile() async {
    final profile = await getCurrentProfile();

    if (profile == null) {
      throw Exception('No profile found for current user.');
    }

    final user = supabase.auth.currentUser;

    return DeviceConfig(
      tenantId: profile['tenant_id'],
      locationId: profile['location_id'],
      configuredBy: user?.id,
      deviceName: 'SecuGen USB Scanner',
      connectionType: 'usb',
      secugenModel: 'Hamster Pro 20 USB',
      vendorId: null,
      productId: null,
      bluetoothMacAddress: null,
      templateFormat: 'secugen_400',
      qualityThreshold: 70,
      matchThreshold: 80,
      livenessEnabled: false,
      isActive: true,
      metadata: {'source': 'flutter_mobile', 'module': 'device_configuration'},
    );
  }
}
