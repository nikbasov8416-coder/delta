import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../default_catalog.dart';
import '../../domain/sync/hlc.dart';
import 'sync_error.dart';

Variable variable(Object? value) => switch (value) {
  String v => Variable.withString(v),
  int v => Variable.withInt(v),
  _ => const Variable<String>(null),
};

/// Только эти таблицы покидают устройство. settings пока целиком локальная.
const syncTables = [
  'currency',
  'liquidity_level',
  'storage',
  'storage_currency',
  'snapshot',
  'snapshot_line',
  'snapshot_rate',
  'audit_log',
  'rate_cache',
];
const naturalKeys = <String, List<String>>{
  'storage_currency': ['storage_id', 'currency_id'],
  'snapshot_line': ['snapshot_id', 'storage_id', 'currency_id'],
  'snapshot_rate': ['snapshot_id', 'currency_id'],
  'rate_cache': ['currency_id', 'date', 'source'],
};

class SyncJournal {
  SyncJournal(this.db, this.clock);
  final AppDatabase db;
  final HybridClock clock;
  static Future<void> install(AppDatabase db) => db.transaction(() async {
    final existing = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='sync_local'",
        )
        .get();
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sync_local (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sync_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, payload TEXT NOT NULL)',
    );
    for (final table in syncTables) {
      final columns = (await db.customSelect('PRAGMA table_info($table)').get())
          .map((r) => r.read<String>('name'))
          .toList();
      final json = columns.map((c) => "'$c',NEW.$c").join(',');
      for (final operation in ['INSERT', 'UPDATE']) {
        final name = 'sync_${table}_${operation.toLowerCase()}';
        await db.customStatement('DROP TRIGGER IF EXISTS $name');
        await db.customStatement(
          'CREATE TRIGGER $name AFTER $operation ON $table '
          "WHEN NOT EXISTS(SELECT 1 FROM sync_local WHERE key='applying' AND value='1') "
          "BEGIN INSERT INTO sync_outbox(entity,payload) VALUES ('$table',json_object($json)); END",
        );
      }
    }
    // Обновление с этапа 3: уже существующие строки тоже должны попасть на Диск.
    if (existing.isEmpty) await enqueueAll(db);
  });

  static Future<void> enqueueAll(AppDatabase db) async {
    for (final table in syncTables) {
      for (final row in await db.customSelect('SELECT * FROM $table').get()) {
        await db.customStatement(
          'INSERT INTO sync_outbox(entity,payload) VALUES (?,?)',
          [table, jsonEncode(row.data)],
        );
      }
    }
  }

  Future<String?> get(String key) async {
    final rows = await db
        .customSelect(
          'SELECT value FROM sync_local WHERE key=?',
          variables: [variable(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('value');
  }

  Future<void> set(String key, String value) => db.customStatement(
    'INSERT OR REPLACE INTO sync_local VALUES (?,?)',
    [key, value],
  );
  Future<bool> hasData() async {
    if ((await db
            .customSelect(
              'SELECT 1 FROM storage UNION ALL SELECT 1 FROM snapshot LIMIT 1',
            )
            .get())
        .isNotEmpty) {
      return true;
    }
    for (final table in ['currency', 'liquidity_level']) {
      final defaults = defaultCatalog(table);
      for (final row in await db.customSelect('SELECT * FROM $table').get()) {
        final original = defaults[row.read<String>('id')];
        // HLC и автор засева различаются между устройствами. Сравниваем значения;
        // пользовательские записи и надгробия тоже требуют предупреждения.
        if (original == null ||
            original.entries.any((e) {
              if (row.data[e.key] == e.value) return false;
              // Старый засев отличался только цветом уровня.
              return table != 'liquidity_level' ||
                  e.key != 'color' ||
                  row.data['color'] !=
                      legacyLiquidityColor(original['sort_order']! as int);
            })) {
          return true;
        }
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> changes() async => [
    for (final row
        in await db
            .customSelect('SELECT * FROM sync_outbox ORDER BY seq LIMIT 300')
            .get())
      {
        'seq': row.read<int>('seq'),
        'table': row.read<String>('entity'),
        'row': jsonDecode(row.read<String>('payload')),
      },
  ];
  Future<List<Map<String, dynamic>>> validate(List<dynamic> entries) async {
    if (entries.length > 300) {
      throw const SyncFailure('Слишком много записей в пачке.');
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in entries) {
      try {
        final table = entry['table'] as String;
        if (!syncTables.contains(table)) throw const FormatException();
        final row = Map<String, dynamic>.from(entry['row'] as Map);
        final columns =
            (await db.customSelect('PRAGMA table_info($table)').get())
                .map((r) => r.read<String>('name'))
                .toSet();
        if (row.keys.toSet().difference(columns).isNotEmpty ||
            columns.difference(row.keys.toSet()).isNotEmpty) {
          throw const SyncFailure(
            'Данные пришли с другой версии Delta. Обновите приложение на этом устройстве',
          );
        }
        if (row.values.any((v) => v != null && v is! String && v is! int) ||
            !RegExp(r'^\d{13}:\d{10}:[a-f0-9-]{36}$')
                .hasMatch(row['updated_at'] as String) ||
            !(row['updated_at'] as String).endsWith(':${row['device_id']}') ||
            !RegExp(r'^[a-f0-9-]{36}$').hasMatch(row['id'] as String) ||
            ![0, 1].contains(row['deleted'])) {
          throw const FormatException();
        }
        result.add({'table': table, 'row': row});
      } on SyncFailure {
        rethrow;
      } catch (_) {
        throw const SyncFailure('Некорректная запись в журнале синхронизации.');
      }
    }
    return result;
  }

  Future<void> apply(List<Map<String, dynamic>> entries) async {
    // Сначала сворачиваем версии одной записи до LWW-победителя. Иначе
    // промежуточная версия из старой пачки может нарушить UNIQUE, хотя итоговая
    // запись уже исправлена пользователем (например, переименован код валюты).
    final latest = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      final row = entry['row'] as Map;
      final key = "${entry['table']}:${row['id']}";
      final old = latest[key]?['row'] as Map?;
      if (old == null ||
          (row['updated_at'] as String).compareTo(old['updated_at'] as String) >
              0) {
        latest[key] = entry;
      }
    }
    for (final entry in latest.values) {
      final table = entry['table'] as String;
      final row = Map<String, dynamic>.from(entry['row'] as Map);
      var old = await db
          .customSelect(
            'SELECT id,updated_at FROM $table WHERE id=?',
            variables: [variable(row['id'])],
          )
          .get();
      if (table == 'currency' && old.isEmpty) {
        final sameCode = await db
            .customSelect(
              'SELECT id FROM currency WHERE code=?',
              variables: [variable(row['code'])],
            )
            .get();
        if (sameCode.isNotEmpty) {
          throw const SyncFailure(
            'Конфликт валют с одинаковым кодом и разными идентификаторами. Переименуйте одну валюту или подключитесь с заменой данных.',
          );
        }
      }
      // У производных строк возможны разные UUID при одновременном создании.
      // Они не являются FK-целями: идентичность задаёт также составной UNIQUE.
      if (old.isEmpty && naturalKeys.containsKey(table)) {
        final keys = naturalKeys[table]!;
        old = await db
            .customSelect(
              'SELECT id,updated_at FROM $table WHERE ${keys.map((k) => '$k=?').join(' AND ')}',
              variables: keys.map((k) => variable(row[k])).toList(),
            )
            .get();
        if (old.isNotEmpty) row['id'] = old.single.read<String>('id');
      }
      clock.observe(row['updated_at'] as String);
      if (old.isNotEmpty &&
          old.single
                  .read<String>('updated_at')
                  .compareTo(row['updated_at'] as String) >=
              0) {
        continue;
      }
      final keys = row.keys.toList();
      await db.customStatement(
        'INSERT INTO $table (${keys.join(',')}) VALUES (${List.filled(keys.length, '?').join(',')}) '
        'ON CONFLICT(id) DO UPDATE SET ${keys.where((k) => k != 'id').map((k) => '$k=excluded.$k').join(',')}',
        row.values.toList(),
      );
    }
  }
}
