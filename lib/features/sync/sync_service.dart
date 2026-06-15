import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../core/storage/local_storage.dart' as app_storage;

class SyncService {
  final supabase = Supabase.instance.client;
  final localStorage = app_storage.LocalStorage();

  Future<int> syncPendingBeneficiaries() async {
    final pending = await localStorage.getPendingBeneficiaries();

    if (pending.isEmpty) return 0;

    for (final item in pending) {
      await supabase.from('beneficiaries').insert(item);
    }

    await localStorage.clearPendingBeneficiaries();

    return pending.length;
  }
}
