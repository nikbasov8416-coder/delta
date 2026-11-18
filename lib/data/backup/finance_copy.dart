import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:drift/native.dart';

import '../../domain/rates/rates.dart';
import '../database/app_database.dart';
import '../database/decimal_sql.dart';
import '../sync/sync_crypto.dart';
import '../sync/sync_error.dart';
import '../sync/sync_service.dart';

const maximumBackupBytes = 64 * 1024 * 1024;
const _magic = 'DELTA-BACKUP';
const _version = 1;
const _tables = [
  'currency',
  'liquidity_level',
  'storage',
  'storage_currency',
  'snapshot',
  'snapshot_line',
  'snapshot_rate',
  'audit_log',
];

typedef FinanceTables = Map<String, List<Map<String, Object?>>>;

Future<FinanceTables> readFinanceTables(
  AppDatabase db, {
  bool includeDeleted = true,
}) => db.transaction(
  () async => {
    for (final table in _tables)
      table: [
        for (final row
            in await db
                .customSelect(
                  'SELECT * FROM $table ${includeDeleted ? '' : 'WHERE deleted=0'} ORDER BY id',
                )
                .get())
          row.data,
      ],
  },
);

class BackupFailure implements Exception {
  const BackupFailure(this.message);
  final String message;
}

class OpenedBackup {
  const OpenedBackup._(this.createdAt, this._tables);
  final DateTime createdAt;
  final FinanceTables _tables;

  Iterable<Map<String, Object?>> get _snapshots =>
      _tables['snapshot']!.where((row) => row['deleted'] == 0);
  int get snapshots => _snapshots.length;
  int get storages =>
      _tables['storage']!.where((row) => row['deleted'] == 0).length;
  String? get lastSnapshot {
    final dates = _snapshots.map((row) => row['date']! as String).toList()
      ..sort();
    return dates.lastOrNull;
  }
}

class FinanceCopy {
  const FinanceCopy(this.sync);
  final SyncService sync;
  AppDatabase get _db => sync.repository.db;

  Future<Uint8List> create(String password) async {
    if (password.isEmpty) throw const BackupFailure('Введите пароль копии.');
    final tables = await readFinanceTables(_db);
    final created = sync.repository.now().toUtc().toIso8601String();
    final salt = SyncCrypto.newSalt();
    final header = jsonEncode({
      'magic': _magic,
      'version': _version,
      'cipher': 'aes-256-gcm',
      'kdf': 'argon2id-v19',
      'memory': SyncCrypto.memory,
      'iterations': SyncCrypto.iterations,
      'parallelism': SyncCrypto.parallelism,
      'salt': base64Encode(salt),
    });
    final headerBytes = utf8.encode(header);
    final payload = utf8.encode(
      jsonEncode({'created_at': created, 'tables': tables}),
    );
    if (payload.length + headerBytes.length + 32 > maximumBackupBytes) {
      throw const BackupFailure(
        'Данные слишком велики для файла резервной копии.',
      );
    }
    final crypto = await SyncCrypto.deriveKey(password, salt);
    final body = await crypto.encrypt(payload, header);
    return (BytesBuilder(copy: false)
          ..add(
            (ByteData(
              4,
            )..setUint32(0, headerBytes.length)).buffer.asUint8List(),
          )
          ..add(headerBytes)
          ..add(body))
        .takeBytes();
  }

  Future<OpenedBackup> open(
    Uint8List bytes,
    String password,
  ) => sync.withoutSync(() async {
    if (password.isEmpty) throw const BackupFailure('Введите пароль копии.');
    if (bytes.length < 32 || bytes.length > maximumBackupBytes) {
      throw const BackupFailure('Размер файла резервной копии недопустим.');
    }
    final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
    if (length < 1 || length > 4096 || length + 32 > bytes.length) {
      throw const BackupFailure(
        'Это не файл резервной копии Delta или он повреждён.',
      );
    }
    late String header;
    late List<int> salt;
    try {
      header = utf8.decode(Uint8List.sublistView(bytes, 4, 4 + length));
      final info = jsonDecode(header) as Map<String, dynamic>;
      if (info['magic'] != _magic) throw const FormatException();
      if (info['version'] != _version) {
        throw const BackupFailure(
          'Версия резервной копии не поддерживается. Обновите Delta.',
        );
      }
      const keys = {
        'magic',
        'version',
        'cipher',
        'kdf',
        'memory',
        'iterations',
        'parallelism',
        'salt',
      };
      if (info.length != keys.length ||
          !info.keys.every(keys.contains) ||
          info['version'] is! int ||
          info['cipher'] != 'aes-256-gcm' ||
          info['kdf'] != 'argon2id-v19' ||
          info['memory'] is! int ||
          info['memory'] != SyncCrypto.memory ||
          info['iterations'] is! int ||
          info['iterations'] != SyncCrypto.iterations ||
          info['parallelism'] is! int ||
          info['parallelism'] != SyncCrypto.parallelism) {
        throw const FormatException();
      }
      salt = base64Decode(info['salt'] as String);
      if (salt.length != 16) throw const FormatException();
    } on BackupFailure {
      rethrow;
    } catch (_) {
      throw const BackupFailure(
        'Это не файл резервной копии Delta или его заголовок повреждён.',
      );
    }
    final crypto = await SyncCrypto.deriveKey(password, salt);
    late Uint8List clear;
    try {
      clear = await crypto.decrypt(
        Uint8List.sublistView(bytes, 4 + length),
        header,
      );
    } on SyncFailure {
      throw const BackupFailure('Неверный пароль копии или файл повреждён.');
    }
    final backup = _decode(clear);
    await _checkInMemory(backup._tables);
    return backup;
  });

  Future<void> restore(OpenedBackup backup) => sync.withoutSync(() async {
    await _replace(_db, backup._tables);
    for (final table in backup._tables.values) {
      for (final row in table) {
        sync.repository.clock.observe(row['updated_at']! as String);
      }
    }
  });

  // Изолированная база проверяет ограничения SQL и ссылки до предпросмотра.
  static Future<void> _checkInMemory(FinanceTables tables) =>
      Isolate.run(() async {
        final validation = AppDatabase(
          NativeDatabase.memory(setup: installDecimalFunctions),
        );
        try {
          await _replace(validation, tables);
        } catch (_) {
          throw const BackupFailure(
            'Некорректные записи или связи в резервной копии.',
          );
        } finally {
          await validation.close();
        }
      });

  static OpenedBackup _decode(Uint8List clear) {
    try {
      final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final created = DateTime.parse(data['created_at'] as String);
      final raw = data['tables'] as Map<String, dynamic>;
      if (data.length != 2 ||
          raw.length != _tables.length ||
          !raw.keys.every(_tables.contains)) {
        throw const FormatException();
      }
      final tables = <String, List<Map<String, Object?>>>{};
      final uuid = RegExp(r'^[a-f0-9-]{36}$');
      final stamp = RegExp(r'^\d{13}:\d{10}:[a-f0-9-]{36}$');
      for (final table in _tables) {
        tables[table] = [
          for (final item in raw[table] as List)
            Map<String, Object?>.from(item as Map),
        ];
        for (final row in tables[table]!) {
          if (!uuid.hasMatch(row['id'] as String) ||
              !uuid.hasMatch(row['device_id'] as String) ||
              !stamp.hasMatch(row['updated_at'] as String) ||
              !(row['updated_at'] as String).endsWith(':${row['device_id']}') ||
              row['deleted'] is! int ||
              ![0, 1].contains(row['deleted']) ||
              row.values.any(
                (value) => value != null && value is! String && value is! int,
              )) {
            throw const FormatException();
          }
          if (table == 'snapshot' &&
              dayKey(DateTime.parse(row['date'] as String)) != row['date']) {
            throw const FormatException();
          }
          if (table == 'audit_log') {
            if (jsonDecode(row['old_value'] as String) is! Map ||
                jsonDecode(row['new_value'] as String) is! Map) {
              throw const FormatException();
            }
          }
        }
      }
      return OpenedBackup._(created, tables);
    } catch (_) {
      throw const BackupFailure('Некорректное содержимое резервной копии.');
    }
  }

  static Future<void> _replace(
    AppDatabase db,
    FinanceTables tables,
  ) => db.transaction(() async {
    await db.customStatement(
      "INSERT OR REPLACE INTO sync_local VALUES ('applying','1')",
    );
    // Кэш относится к прежнему набору валют и не входит в копию.
    await db.customStatement('DELETE FROM rate_cache');
    for (final table in _tables.reversed) {
      await db.customStatement('DELETE FROM $table');
    }
    for (final table in _tables) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      final keys = columns
          .map((column) => column.read<String>('name'))
          .toList();
      final placeholders = List.filled(keys.length, '?').join(',');
      final insert =
          'INSERT INTO $table (${keys.join(',')}) VALUES ($placeholders)';
      for (final row in tables[table]!) {
        if (row.length != keys.length || !keys.every(row.containsKey)) {
          throw const FormatException();
        }
        for (final column in columns) {
          final value = row[column.read<String>('name')];
          if (value == null
              ? column.read<int>('notnull') != 0
              : column.read<String>('type') == 'INTEGER'
              ? value is! int
              : value is! String) {
            throw const FormatException();
          }
        }
        await db.customStatement(insert, [for (final key in keys) row[key]]);
      }
    }
    await db.customStatement('DELETE FROM sync_outbox');
    await db.customStatement("DELETE FROM sync_local WHERE key='applying'");
    final invalid = await db.customSelect('PRAGMA foreign_key_check').get();
    if (invalid.isNotEmpty) throw const FormatException();
  });
}
