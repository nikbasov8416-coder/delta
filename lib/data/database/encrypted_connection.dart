import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'decimal_sql.dart';

/// Настройка допускает повторные вызовы для новых соединений тем же executor.
/// Нельзя обнулять захваченную копию после первого setup. Владелец executor
/// закрывает его при блокировке; новое открытие читает ключ из secure storage.
DatabaseSetup encryptedSetup(Uint8List key) {
  if (key.length != 32) throw ArgumentError('Нужен ключ длиной 256 бит');
  final copy = Uint8List.fromList(key);
  return (database) {
    final version = database.select('PRAGMA cipher_version');
    if (version.isEmpty || version.first.values.first.toString().isEmpty) {
      throw StateError('SQLCipher недоступен: открытие базы запрещено');
    }
    final hex = copy
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    database.execute('PRAGMA key = "x\'$hex\'"');
    database.select('SELECT count(*) FROM sqlite_master');
    database.execute('PRAGMA foreign_keys = ON');
    installDecimalFunctions(database);
  };
}

QueryExecutor encryptedConnection(File file, Uint8List key) =>
    NativeDatabase.createInBackground(
      file,
      logStatements: false,
      setup: encryptedSetup(key),
    );
