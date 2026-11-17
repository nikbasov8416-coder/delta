import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'sync_error.dart';

class SyncCrypto {
  SyncCrypto(this.key);
  final SecretKey key;
  static final _cipher = AesGcm.with256bits();
  static const memory = 19456, iterations = 2, parallelism = 1;
  static const checkText = 'Delta sync key check v1';

  static Map<String, dynamic> header() => {
    'format': 1,
    'dataset': const Uuid().v4(),
    'cipher': 'aes-256-gcm',
    'kdf': 'argon2id-v19',
    'memory': memory,
    'iterations': iterations,
    'parallelism': parallelism,
    'salt': base64Encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    ),
  };
  static void validate(Map<String, dynamic> meta) {
    try {
      if (meta['format'] != 1 ||
          meta['cipher'] != 'aes-256-gcm' ||
          meta['kdf'] != 'argon2id-v19' ||
          meta['memory'] != memory ||
          meta['iterations'] != iterations ||
          meta['parallelism'] != parallelism ||
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(meta['dataset'] as String) ||
          base64Decode(meta['salt'] as String).length != 16) {
        throw const FormatException();
      }
    } catch (_) {
      throw const SyncFailure(
        'Неподдерживаемый или повреждённый формат синхронизации.',
      );
    }
  }

  static Future<SyncCrypto> derive(
    String phrase,
    Map<String, dynamic> meta,
  ) async {
    validate(meta);
    if (phrase.isEmpty) {
      throw const SyncFailure('Введите парольную фразу синхронизации.');
    }
    final salt = base64Decode(meta['salt'] as String);
    // Тяжёлая KDF не блокирует интерфейс. Параметры meta строго ограничены.
    final bytes = await Isolate.run(() async {
      final key = await Argon2id(
        memory: memory,
        iterations: iterations,
        parallelism: parallelism,
        hashLength: 32,
      ).deriveKey(secretKey: SecretKey(utf8.encode(phrase)), nonce: salt);
      return key.extractBytes();
    });
    return SyncCrypto(SecretKey(bytes));
  }

  static String checkAad(Map<String, dynamic> m) => jsonEncode([
    m['format'],
    m['dataset'],
    m['cipher'],
    m['kdf'],
    m['memory'],
    m['iterations'],
    m['parallelism'],
    m['salt'],
  ]);
  Future<Uint8List> encrypt(List<int> data, String aad) async {
    final box = await _cipher.encrypt(
      data,
      secretKey: key,
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList(box.concatenation());
  }

  Future<Uint8List> decrypt(List<int> bytes, String aad) async {
    try {
      if (bytes.length < 28) throw const FormatException();
      return Uint8List.fromList(
        await _cipher.decrypt(
          SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
          secretKey: key,
          aad: utf8.encode(aad),
        ),
      );
    } catch (_) {
      throw const SyncFailure('Повреждена зашифрованная пачка синхронизации.');
    }
  }

  Future<void> check(Map<String, dynamic> meta) async {
    validate(meta);
    try {
      final clear = await decrypt(
        base64Decode(meta['check'] as String),
        checkAad(meta),
      );
      if (utf8.decode(clear) != checkText) throw const FormatException();
    } catch (_) {
      throw const SyncFailure(
        'Неверная парольная фраза или повреждён файл настройки синхронизации.',
      );
    }
  }
}
