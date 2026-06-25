import '../../core/database/local_sync_queue.dart';
import 'sync_queue_processor.dart';
import 'sync_result.dart';

class SyncService {
  SyncService({SyncQueueProcessor? processor, LocalSyncQueue? syncQueue})
    : _processor = processor ?? SyncQueueProcessor(),
      _syncQueue = syncQueue ?? LocalSyncQueue();

  final SyncQueueProcessor _processor;
  final LocalSyncQueue _syncQueue;

  Future<SyncResult> syncOfflineData() {
    return _processor.process();
  }

  Future<int> syncPendingBeneficiaries() async {
    final result = await syncOfflineData();
    return result.successCount;
  }

  Future<int> pendingCount() {
    return _syncQueue.pendingCount();
  }

  Future<LocalSyncSummary> summary() {
    return _syncQueue.summary();
  }

  Future<List<Map<String, dynamic>>> recentLogs({int limit = 20}) {
    return _syncQueue.recentLogs(limit: limit);
  }
}
