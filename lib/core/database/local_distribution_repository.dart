import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'encrypted_database.dart';

class LocalDistributionRepository {
  LocalDistributionRepository({EncryptedDatabase? encryptedDatabase})
    : _encryptedDatabase = encryptedDatabase ?? EncryptedDatabase();

  final EncryptedDatabase _encryptedDatabase;
  final Uuid _uuid = const Uuid();

  Future<String> savePendingDistribution({
    required String tenantId,
    required String programId,
    String? beneficiaryId,
    String? localBeneficiaryId,
    required String distributedBy,
    required Map<String, dynamic> payload,
    String? localId,
  }) async {
    final database = await _encryptedDatabase.database;
    final now = DateTime.now().toIso8601String();
    final id = localId ?? _uuid.v4();

    await database.insert('pending_distribution_events', {
      'local_id': id,
      'remote_id': null,
      'tenant_id': tenantId,
      'program_id': programId,
      'beneficiary_id': beneficiaryId,
      'local_beneficiary_id': localBeneficiaryId,
      'distributed_by': distributedBy,
      'payload_json': jsonEncode(payload),
      'sync_status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return id;
  }

  Future<List<PendingDistributionRecord>> recordsForSync({
    int limit = 20,
  }) async {
    final database = await _encryptedDatabase.database;
    final rows = await database.query(
      'pending_distribution_events',
      where: "sync_status IN ('pending', 'failed')",
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(PendingDistributionRecord.fromRow).toList();
  }

  Future<void> updateRemoteBeneficiaryId({
    required String localBeneficiaryId,
    required String remoteBeneficiaryId,
  }) async {
    final database = await _encryptedDatabase.database;
    await database.update(
      'pending_distribution_events',
      {
        'beneficiary_id': remoteBeneficiaryId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_beneficiary_id = ?',
      whereArgs: [localBeneficiaryId],
    );
  }

  Future<void> markSyncing(String localId) async {
    await _update(localId, {
      'sync_status': 'syncing',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markSynced({
    required String localId,
    required String remoteId,
  }) async {
    await _update(localId, {
      'remote_id': remoteId,
      'sync_status': 'synced',
      'last_error': null,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markFailed({
    required String localId,
    required String error,
  }) async {
    final database = await _encryptedDatabase.database;
    await database.rawUpdate(
      '''
      UPDATE pending_distribution_events
      SET sync_status = 'failed',
          retry_count = retry_count + 1,
          last_error = ?,
          updated_at = ?
      WHERE local_id = ?
      ''',
      [error, DateTime.now().toIso8601String(), localId],
    );
  }

  Future<void> _update(String localId, Map<String, Object?> values) async {
    final database = await _encryptedDatabase.database;
    await database.update(
      'pending_distribution_events',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}

class PendingDistributionRecord {
  const PendingDistributionRecord({
    required this.localId,
    required this.remoteId,
    required this.tenantId,
    required this.programId,
    required this.beneficiaryId,
    required this.localBeneficiaryId,
    required this.distributedBy,
    required this.payload,
    required this.syncStatus,
    required this.retryCount,
    required this.lastError,
  });

  final String localId;
  final String? remoteId;
  final String tenantId;
  final String programId;
  final String? beneficiaryId;
  final String? localBeneficiaryId;
  final String distributedBy;
  final Map<String, dynamic> payload;
  final String syncStatus;
  final int retryCount;
  final String? lastError;

  factory PendingDistributionRecord.fromRow(Map<String, Object?> row) {
    return PendingDistributionRecord(
      localId: row['local_id']?.toString() ?? '',
      remoteId: row['remote_id']?.toString(),
      tenantId: row['tenant_id']?.toString() ?? '',
      programId: row['program_id']?.toString() ?? '',
      beneficiaryId: row['beneficiary_id']?.toString(),
      localBeneficiaryId: row['local_beneficiary_id']?.toString(),
      distributedBy: row['distributed_by']?.toString() ?? '',
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload_json']?.toString() ?? '{}') as Map,
      ),
      syncStatus: row['sync_status']?.toString() ?? 'pending',
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
    );
  }
}
