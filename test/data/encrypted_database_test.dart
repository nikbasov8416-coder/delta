import 'dart:io';
import 'dart:typed_data';

import 'package:delta/data/database/app_database.dart';
import 'package:delta/data/database/encrypted_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SQLCipher: файл зашифрован, верный ключ читает, неверный — нет',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'delta-cipher-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/sample.db');
      // Предсказуемый ключ допустим только в этом тесте с выдуманными данными.
      final key = Uint8List.fromList(List.generate(32, (index) => index));
      const marker = 'synthetic-record-for-encryption-test';

      final original = AppDatabase(encryptedConnection(file, key));
      try {
        final version = await original
            .customSelect('PRAGMA cipher_version')
            .get();
        expect(version, isNotEmpty);
        await original.customStatement(
          'CREATE TABLE sample (amount TEXT NOT NULL)',
        );
        await original.customStatement('INSERT INTO sample VALUES (?)', [
          marker,
        ]);
      } finally {
        await original.close();
      }

      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes);
      expect(content.startsWith('SQLite format 3'), isFalse);
      expect(content.contains(marker), isFalse);

      final reopened = AppDatabase(encryptedConnection(file, key));
      try {
        final row = await reopened
            .customSelect('SELECT amount FROM sample')
            .getSingle();
        expect(row.read<String>('amount'), marker);
      } finally {
        await reopened.close();
      }

      final wrong = AppDatabase(encryptedConnection(file, Uint8List(32)));
      try {
        await expectLater(
          wrong.customSelect('SELECT amount FROM sample').get(),
          throwsA(isA<Exception>()),
        );
      } finally {
        await wrong.close();
      }
    },
  );

  test('Ключ неверной длины отклоняется до открытия файла', () {
    expect(
      () => encryptedConnection(File('unused.db'), Uint8List(31)),
      throwsArgumentError,
    );
  });
}
