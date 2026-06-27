import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'encrypted_database.dart';

class LocalQuestionnaireRepository {
  LocalQuestionnaireRepository({EncryptedDatabase? encryptedDatabase})
    : _encryptedDatabase = encryptedDatabase ?? EncryptedDatabase();

  final EncryptedDatabase _encryptedDatabase;
  final Uuid _uuid = const Uuid();

  Future<String> savePendingResponse({
    required String localBeneficiaryId,
    String? remoteBeneficiaryId,
    required String tenantId,
    required String programId,
    required String questionnaireId,
    required String submittedBy,
    required Map<String, dynamic> answers,
    String? localId,
  }) async {
    final database = await _encryptedDatabase.database;
    final now = DateTime.now().toIso8601String();
    final id = localId ?? _uuid.v4();

    await database.insert(
      'pending_questionnaire_responses',
      {
        'local_id': id,
        'remote_response_id': null,
        'local_beneficiary_id': localBeneficiaryId,
        'remote_beneficiary_id': remoteBeneficiaryId,
        'tenant_id': tenantId,
        'program_id': programId,
        'questionnaire_id': questionnaireId,
        'submitted_by': submittedBy,
        'answers_json': jsonEncode(answers),
        'sync_status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  Future<List<PendingQuestionnaireResponseRecord>> recordsForSync({
    int limit = 20,
  }) async {
    final database = await _encryptedDatabase.database;
    final rows = await database.query(
      'pending_questionnaire_responses',
      where: "sync_status IN ('pending', 'failed')",
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(PendingQuestionnaireResponseRecord.fromRow).toList();
  }

  Future<void> updateRemoteBeneficiaryId({
    required String localBeneficiaryId,
    required String remoteBeneficiaryId,
  }) async {
    final database = await _encryptedDatabase.database;
    await database.update(
      'pending_questionnaire_responses',
      {
        'remote_beneficiary_id': remoteBeneficiaryId,
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
    required String remoteResponseId,
  }) async {
    await _update(localId, {
      'remote_response_id': remoteResponseId,
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
      UPDATE pending_questionnaire_responses
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
      'pending_questionnaire_responses',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}

class PendingQuestionnaireResponseRecord {
  const PendingQuestionnaireResponseRecord({
    required this.localId,
    required this.remoteResponseId,
    required this.localBeneficiaryId,
    required this.remoteBeneficiaryId,
    required this.tenantId,
    required this.programId,
    required this.questionnaireId,
    required this.submittedBy,
    required this.answers,
    required this.syncStatus,
    required this.retryCount,
    required this.lastError,
  });

  final String localId;
  final String? remoteResponseId;
  final String localBeneficiaryId;
  final String? remoteBeneficiaryId;
  final String tenantId;
  final String programId;
  final String questionnaireId;
  final String submittedBy;
  final Map<String, dynamic> answers;
  final String syncStatus;
  final int retryCount;
  final String? lastError;

  factory PendingQuestionnaireResponseRecord.fromRow(Map<String, Object?> row) {
    return PendingQuestionnaireResponseRecord(
      localId: row['local_id']?.toString() ?? '',
      remoteResponseId: row['remote_response_id']?.toString(),
      localBeneficiaryId: row['local_beneficiary_id']?.toString() ?? '',
      remoteBeneficiaryId: row['remote_beneficiary_id']?.toString(),
      tenantId: row['tenant_id']?.toString() ?? '',
      programId: row['program_id']?.toString() ?? '',
      questionnaireId: row['questionnaire_id']?.toString() ?? '',
      submittedBy: row['submitted_by']?.toString() ?? '',
      answers: Map<String, dynamic>.from(
        jsonDecode(row['answers_json']?.toString() ?? '{}') as Map,
      ),
      syncStatus: row['sync_status']?.toString() ?? 'pending',
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
    );
  }
}
