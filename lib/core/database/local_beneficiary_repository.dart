import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'encrypted_database.dart';

class LocalBeneficiaryRepository {
  LocalBeneficiaryRepository({EncryptedDatabase? encryptedDatabase})
    : _encryptedDatabase = encryptedDatabase ?? EncryptedDatabase();

  final EncryptedDatabase _encryptedDatabase;
  final Uuid _uuid = const Uuid();

  Future<String> savePendingBeneficiary({
    required Map<String, dynamic> payload,
    required String tenantId,
    required String programId,
    required String locationId,
    required String createdBy,
    String? photoLocalPath,
    String? facePhotoLocalPath,
    String? localId,
  }) async {
    final database = await _encryptedDatabase.database;
    final now = DateTime.now().toIso8601String();
    final id = localId ?? _uuid.v4();

    await database.insert('pending_beneficiaries', {
      'local_id': id,
      'remote_id': null,
      'tenant_id': tenantId,
      'program_id': programId,
      'location_id': locationId,
      'created_by': createdBy,
      'payload_json': jsonEncode(payload),
      'photo_local_path': photoLocalPath,
      'face_photo_local_path': facePhotoLocalPath,
      'sync_status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return id;
  }

  Future<List<PendingBeneficiaryRecord>> recordsForSync({
    int limit = 20,
  }) async {
    final database = await _encryptedDatabase.database;
    final rows = await database.query(
      'pending_beneficiaries',
      where: "sync_status IN ('pending', 'failed')",
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(PendingBeneficiaryRecord.fromRow).toList();
  }

  Future<PendingBeneficiaryRecord?> findByLocalId(String localId) async {
    final database = await _encryptedDatabase.database;
    final rows = await database.query(
      'pending_beneficiaries',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PendingBeneficiaryRecord.fromRow(rows.first);
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
    String? photoPath,
    String? facePhotoPath,
  }) async {
    final record = await findByLocalId(localId);
    final payload = record == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(record.payload);

    if (photoPath != null) {
      payload['photo_url'] = photoPath;
    }
    if (facePhotoPath != null) {
      payload['face_photo_url'] = facePhotoPath;
    }

    await _update(localId, {
      'remote_id': remoteId,
      'payload_json': jsonEncode(payload),
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
    final now = DateTime.now().toIso8601String();

    await database.rawUpdate(
      '''
      UPDATE pending_beneficiaries
      SET sync_status = 'failed',
          retry_count = retry_count + 1,
          last_error = ?,
          updated_at = ?
      WHERE local_id = ?
      ''',
      [error, now, localId],
    );
  }

  Future<void> updateRemoteId({
    required String localId,
    required String remoteId,
  }) async {
    await _update(localId, {
      'remote_id': remoteId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _update(String localId, Map<String, Object?> values) async {
    final database = await _encryptedDatabase.database;
    await database.update(
      'pending_beneficiaries',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}

class PendingBeneficiaryRecord {
  const PendingBeneficiaryRecord({
    required this.localId,
    required this.remoteId,
    required this.tenantId,
    required this.programId,
    required this.locationId,
    required this.createdBy,
    required this.payload,
    required this.photoLocalPath,
    required this.facePhotoLocalPath,
    required this.syncStatus,
    required this.retryCount,
    required this.lastError,
  });

  final String localId;
  final String? remoteId;
  final String tenantId;
  final String programId;
  final String locationId;
  final String createdBy;
  final Map<String, dynamic> payload;
  final String? photoLocalPath;
  final String? facePhotoLocalPath;
  final String syncStatus;
  final int retryCount;
  final String? lastError;

  factory PendingBeneficiaryRecord.fromRow(Map<String, Object?> row) {
    return PendingBeneficiaryRecord(
      localId: row['local_id']?.toString() ?? '',
      remoteId: row['remote_id']?.toString(),
      tenantId: row['tenant_id']?.toString() ?? '',
      programId: row['program_id']?.toString() ?? '',
      locationId: row['location_id']?.toString() ?? '',
      createdBy: row['created_by']?.toString() ?? '',
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload_json']?.toString() ?? '{}') as Map,
      ),
      photoLocalPath: row['photo_local_path']?.toString(),
      facePhotoLocalPath: row['face_photo_local_path']?.toString(),
      syncStatus: row['sync_status']?.toString() ?? 'pending',
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
    );
  }
}
