import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class EncryptedDatabase {
  EncryptedDatabase({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _databaseName = 'verify_aid_offline.db';
  static const _databaseVersion = 1;
  static const _databaseKeyName = 'verify_aid_sqlcipher_key';

  final FlutterSecureStorage _secureStorage;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final directory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(directory.path, _databaseName);
    final password = await _getOrCreateDatabaseKey();

    _database = await openDatabase(
      databasePath,
      password: password,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    );

    return _database!;
  }

  Future<void> close() async {
    final existing = _database;
    if (existing == null) return;

    await existing.close();
    _database = null;
  }

  Future<String> _getOrCreateDatabaseKey() async {
    final storedKey = await _secureStorage.read(key: _databaseKeyName);
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }

    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final key = base64UrlEncode(bytes);

    await _secureStorage.write(key: _databaseKeyName, value: key);
    return key;
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE pending_beneficiaries (
        local_id TEXT PRIMARY KEY,
        remote_id TEXT,
        tenant_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        location_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        photo_local_path TEXT,
        face_photo_local_path TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE pending_questionnaire_responses (
        local_id TEXT PRIMARY KEY,
        remote_response_id TEXT,
        local_beneficiary_id TEXT,
        remote_beneficiary_id TEXT,
        tenant_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        questionnaire_id TEXT NOT NULL,
        submitted_by TEXT NOT NULL,
        answers_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE pending_distribution_events (
        local_id TEXT PRIMARY KEY,
        remote_id TEXT,
        tenant_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        beneficiary_id TEXT,
        local_beneficiary_id TEXT,
        distributed_by TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        local_id TEXT,
        operation TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_pending_beneficiaries_status '
      'ON pending_beneficiaries(sync_status, created_at)',
    );
    await database.execute(
      'CREATE INDEX idx_pending_questionnaire_status '
      'ON pending_questionnaire_responses(sync_status, created_at)',
    );
    await database.execute(
      'CREATE INDEX idx_pending_questionnaire_beneficiary '
      'ON pending_questionnaire_responses(local_beneficiary_id)',
    );
    await database.execute(
      'CREATE INDEX idx_pending_distribution_status '
      'ON pending_distribution_events(sync_status, created_at)',
    );
    await database.execute(
      'CREATE INDEX idx_sync_logs_created_at ON sync_logs(created_at)',
    );
  }
}
