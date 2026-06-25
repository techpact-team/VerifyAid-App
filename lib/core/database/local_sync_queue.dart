import 'package:sqflite_sqlcipher/sqflite.dart';

import 'encrypted_database.dart';

class LocalSyncQueue {
  LocalSyncQueue({EncryptedDatabase? encryptedDatabase})
    : _encryptedDatabase = encryptedDatabase ?? EncryptedDatabase();

  final EncryptedDatabase _encryptedDatabase;

  Future<int> pendingCount() async {
    final database = await _encryptedDatabase.database;

    final counts = await Future.wait([
      _countByStatus(database, 'pending_beneficiaries'),
      _countByStatus(database, 'pending_questionnaire_responses'),
      _countByStatus(database, 'pending_distribution_events'),
    ]);

    return counts.fold<int>(0, (total, count) => total + count);
  }

  Future<LocalSyncSummary> summary() async {
    final database = await _encryptedDatabase.database;

    final rows = await Future.wait([
      _statusCounts(database, 'pending_beneficiaries'),
      _statusCounts(database, 'pending_questionnaire_responses'),
      _statusCounts(database, 'pending_distribution_events'),
    ]);

    final combined = <String, int>{
      'pending': 0,
      'syncing': 0,
      'synced': 0,
      'failed': 0,
    };

    for (final tableCounts in rows) {
      for (final entry in tableCounts.entries) {
        combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
      }
    }

    final logs = await database.query(
      'sync_logs',
      orderBy: 'created_at DESC',
      limit: 1,
    );

    return LocalSyncSummary(
      pending: combined['pending'] ?? 0,
      syncing: combined['syncing'] ?? 0,
      synced: combined['synced'] ?? 0,
      failed: combined['failed'] ?? 0,
      lastSyncTime: logs.isEmpty
          ? null
          : DateTime.tryParse(logs.first['created_at']?.toString() ?? ''),
    );
  }

  Future<List<Map<String, dynamic>>> recentLogs({int limit = 20}) async {
    final database = await _encryptedDatabase.database;

    return database.query(
      'sync_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> log({
    required String entityType,
    required String operation,
    required String status,
    String? localId,
    String? message,
  }) async {
    final database = await _encryptedDatabase.database;

    await database.insert('sync_logs', {
      'entity_type': entityType,
      'local_id': localId,
      'operation': operation,
      'status': status,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> resetInterruptedSyncs() async {
    final database = await _encryptedDatabase.database;
    final now = DateTime.now().toIso8601String();

    for (final table in const [
      'pending_beneficiaries',
      'pending_questionnaire_responses',
      'pending_distribution_events',
    ]) {
      await database.update(table, {
        'sync_status': 'pending',
        'updated_at': now,
      }, where: "sync_status = 'syncing'");
    }
  }

  Future<int> _countByStatus(Database database, String table) async {
    final result = await database.rawQuery('''
      SELECT COUNT(*) AS count
      FROM $table
      WHERE sync_status IN ('pending', 'failed')
      ''');

    return result.first['count'] as int? ?? 0;
  }

  Future<Map<String, int>> _statusCounts(
    Database database,
    String table,
  ) async {
    final result = await database.rawQuery('''
      SELECT sync_status, COUNT(*) AS count
      FROM $table
      GROUP BY sync_status
      ''');

    return {
      for (final row in result)
        row['sync_status'].toString(): row['count'] as int? ?? 0,
    };
  }
}

class LocalSyncSummary {
  const LocalSyncSummary({
    required this.pending,
    required this.syncing,
    required this.synced,
    required this.failed,
    required this.lastSyncTime,
  });

  final int pending;
  final int syncing;
  final int synced;
  final int failed;
  final DateTime? lastSyncTime;

  int get total => pending + syncing + synced + failed;
}
