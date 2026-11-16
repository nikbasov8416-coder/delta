import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'secret_store.dart';

class VaultKeys {
  VaultKeys(this.store);
  final SecretStore store;

  /// При потере ключа существующий файл не перезаписывается и не удаляется.
  Future<Uint8List> databaseKey(File database) async {
    final saved = await store.read('database_key_v1');
    if (saved != null) {
      final key = base64Decode(saved);
      if (key.length != 32) throw StateError('Повреждён сохранённый ключ базы');
      return key;
    }
    if (await database.exists()) {
      throw StateError(
        'Ключ существующей базы недоступен. Восстановление требует резервной копии; файл не изменён.',
      );
    }
    final random = Random.secure();
    final key = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    await store.write('database_key_v1', base64Encode(key));
    return key;
  }

  Future<String> deviceId() async {
    final saved = await store.read('device_id_v1');
    if (saved != null) return saved;
    final id = const Uuid().v4();
    await store.write('device_id_v1', id);
    return id;
  }
}
