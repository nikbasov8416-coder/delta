import 'dart:io';
import 'dart:typed_data';

import 'package:delta/data/database/app_database.dart';
import 'package:delta/data/database/encrypted_connection.dart';
import 'package:delta/data/finance_repository.dart';
import 'package:delta/data/sync/sync_journal.dart';
import 'package:delta/domain/sync/hlc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('SQLCipher v3 → v4: данные сохранены, bootstrap однократный, новые записи попадают в очередь', () async {
    final directory = await Directory.systemTemp.createTemp(
      'delta-sync-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/synthetic.db');
    final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
    const id = '00000000-0000-4000-8000-000000000001';
    final old = sqlite3.open(file.path);
    try {
      encryptedSetup(key)(old);
      old.execute(File('lib/data/database/schema.drift').readAsStringSync());
      old.execute('PRAGMA user_version=3');
      old.execute('INSERT INTO currency VALUES (?,?,?,?,?,?,?,?,?)', [
        id,
        '1700000000000:0000000000:$id',
        id,
        0,
        'RUB',
        'fiat',
        2,
        'Выдуманный рубль',
        'cbr',
      ]);
    } finally {
      old.close();
    }
    for (var open = 0; open < 2; open++) {
      final repo = DriftFinanceRepository(
        AppDatabase(encryptedConnection(file, key)),
        id,
      );
      try {
        final journal = SyncJournal(repo.db, HybridClock(id));
        final rows = await repo.query('SELECT * FROM currency');
        expect(rows.single.text('name'), 'Выдуманный рубль');
        final changes = await journal.changes();
        expect(changes, hasLength(1));
        expect(changes.single['table'], 'currency');
        expect(
          (await repo.db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          4,
        );
        expect(
          await repo.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await repo.close();
      }
    }
  });
}
