class SyncResult {
  const SyncResult({
    required this.startedAt,
    required this.finishedAt,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.messages,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final List<String> messages;

  bool get hasFailures => failedCount > 0;

  int get processedCount => successCount + failedCount + skippedCount;

  String get summary {
    if (processedCount == 0) {
      return 'No offline records to sync.';
    }

    return 'Synced $successCount, failed $failedCount, skipped $skippedCount.';
  }

  factory SyncResult.empty(DateTime startedAt) {
    return SyncResult(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      successCount: 0,
      failedCount: 0,
      skippedCount: 0,
      messages: const [],
    );
  }
}
