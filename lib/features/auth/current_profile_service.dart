import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrentProfileService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint('No authenticated user found');
      return null;
    }

    debugPrint('Current user id: ${user.id}');

    final profile = await supabase
        .from('profiles')
        .select('''
          id,
          full_name,
          email,
          tenant_id,
          role_id,
          location_id,
          status
        ''')
        .eq('id', user.id)
        .maybeSingle();

    debugPrint('Profile result: $profile');

    return profile;
  }
}
