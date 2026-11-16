import 'dart:io';

import 'package:delta/data/security/vault_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  test(
    'Сохранённый ключ повторно читается; потеря ключа не уничтожает файл',
    () async {
      final directory = await Directory.systemTemp.createTemp('delta-keys-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.db'),
          store = MemorySecrets();
      final first = await VaultKeys(store).databaseKey(file);
      expect(first.length, 32);
      expect(await VaultKeys(store).databaseKey(file), first);
      await file.writeAsString('synthetic-file');
      final empty = MemorySecrets();
      await expectLater(VaultKeys(empty).databaseKey(file), throwsStateError);
      expect(await file.readAsString(), 'synthetic-file');
      expect(empty.values, isEmpty);
    },
  );
}
