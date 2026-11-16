import 'dart:io';
import 'dart:typed_data';

import 'package:delta/data/database/app_database.dart';
import 'package:delta/data/database/encrypted_connection.dart';
import 'package:delta/data/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('Миграция пустого каркаса v1 в ядро v3 и повторное открытие', () async {
    final directory = await Directory.systemTemp.createTemp('delta-migration-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.db');
    final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final old = sqlite3.open(file.path);
    encryptedSetup(key)(old);
    old.execute('PRAGMA user_version=1');
    old.close();
    for (var i = 0; i < 2; i++) {
      final db = AppDatabase(encryptedConnection(file, key));
      final repo = DriftFinanceRepository(
        db,
        '00000000-0000-4000-8000-000000000001',
      );
      try {
        await repo.initialize();
        expect((await repo.overview()).currencies.length, 6);
        final version = await db
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.single, 3);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await repo.close();
      }
    }
  });
}
