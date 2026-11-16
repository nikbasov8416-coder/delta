import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Подключение к SQLCipher, который поставляет build hook sqlite3.
/// Ключ предоставляет secure storage (этап 2); запасного открытого режима нет.
QueryExecutor encryptedConnection(File file, Uint8List key) {
  if (key.length != 32) {
    throw ArgumentError('Нужен ключ длиной 256 бит');
  }
  // Копия защищает от изменения вызывающей стороной до открытия фонового подключения.
  final keyCopy = Uint8List.fromList(key);
  return NativeDatabase.createInBackground(
    file,
    logStatements: false,
    setup: (database) {
      try {
        final version = database.select('PRAGMA cipher_version');
        if (version.isEmpty || version.first.values.first.toString().isEmpty) {
          throw StateError('SQLCipher недоступен: открытие базы запрещено');
        }
        final hex = keyCopy
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        database.execute('PRAGMA key = "x\'$hex\'"');
        // Чтение проверяет ключ для существующего файла до работы drift.
        database.select('SELECT count(*) FROM sqlite_master');
        database.execute('PRAGMA foreign_keys = ON');
      } finally {
        keyCopy.fillRange(0, keyCopy.length, 0);
      }
    },
  );
}
