import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:delta/data/database/app_database.dart';
import 'package:delta/data/database/encrypted_connection.dart';
import 'package:delta/data/finance_repository.dart';

void main() {
  test('Зашифрованная v2 → v3 сохраняет строки, ставки и назначает дату старым курсам', () async {
    final directory = await Directory.systemTemp.createTemp('delta-v3-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/synthetic.db');
    final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final old = sqlite3.open(file.path);
    encryptedSetup(key)(old);
    String id(int n) =>
        '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
    void insert(String table, Map<String, Object?> values) {
      final all = {
        'updated_at': '0000000000001:0000000000:sample',
        'device_id': id(99),
        'deleted': 0,
        ...values,
      };
      old.execute(
        'INSERT INTO $table (${all.keys.join(',')}) VALUES (${List.filled(all.length, '?').join(',')})',
        all.values.toList(),
      );
    }

    try {
      old.execute(File('test/fixtures/schema_v2.sql').readAsStringSync());
      old.execute('PRAGMA user_version=2');
      insert('currency', {
        'id': id(1),
        'code': 'USD',
        'kind': 'fiat',
        'precision': 2,
        'name': 'Выдуманная',
        'rate_source': 'cbr',
      });
      insert('liquidity_level', {
        'id': id(2),
        'name': 'Выдуманная',
        'color': 1,
      });
      insert('storage', {
        'id': id(3),
        'name': 'Выдуманное',
        'type': 'cash',
        'liquidity_id': id(2),
      });
      insert('snapshot', {
        'id': id(4),
        'date': '2026-01-10',
        'status': 'fixed',
        'created_at': '2026-01-10T00:00:00Z',
      });
      insert('snapshot_line', {
        'id': id(5),
        'snapshot_id': id(4),
        'storage_id': id(3),
        'currency_id': id(1),
        'liquidity_id': id(2),
        'amount': '10',
        'family_amount': '2',
        'confirmed': 1,
      });
      insert('snapshot_rate', {
        'id': id(6),
        'snapshot_id': id(4),
        'currency_id': id(1),
        'rate': '2',
        'source': 'manual',
        'fetched_at': '2026-01-10T00:00:00Z',
      });
      insert('rate_cache', {
        'id': id(7),
        'currency_id': id(1),
        'date': '2026-01-10',
        'rate': '3',
        'source': 'cbr',
      });
    } finally {
      old.close();
    }
    final repo = DriftFinanceRepository(
      AppDatabase(encryptedConnection(file, key)),
      id(99),
    );
    try {
      await repo.initialize();
      final detail = await repo.snapshot(id(4));
      expect(detail.lines.single.text('amount'), '10');
      expect(detail.rates.single.text('rate'), '2');
      expect(detail.rates.single.text('rate_date'), '2026-01-10');
      expect(detail.rates.single.text('effective_at'), '2026-01-10T00:00:00Z');
      expect(
        (await repo.query('SELECT * FROM rate_cache WHERE id=?', [
          id(7),
        ])).single.text('fetched_at'),
        '',
      );
      expect(
        (await repo.db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        3,
      );
      expect((await repo.totals(id(4))).rubles.total.toString(), '20');
    } finally {
      await repo.close();
    }
  });
}
