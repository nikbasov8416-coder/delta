import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Хранилище передаётся функциями: доменный код не зависит от платформы.
class PinService {
  PinService({
    required this.read,
    required this.write,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) write;
  final DateTime Function() now;
  static const iterations = 310000;
  bool _busy = false;

  Future<bool> get configured async => await read('pin_v1') != null;

  Future<Duration> delay() async {
    final state = jsonDecode(
      await read('pin_failures_v1') ?? '{}',
    ) as Map<String, dynamic>;
    final until = DateTime.fromMillisecondsSinceEpoch(
      (state['until'] as int?) ?? 0,
    );
    final difference = until.difference(now());
    return difference.isNegative ? Duration.zero : difference;
  }

  Future<List<int>> _derive(String pin, List<int> salt, int count) async =>
      (await Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: count,
            bits: 256,
          ).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt))
          .extractBytes();

  Future<void> create(String pin) async {
    if (_busy) throw StateError('Проверка уже выполняется');
    _busy = true;
    try {
      if (await configured) throw StateError('PIN уже задан');
      if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
        throw const FormatException('Нужен PIN из 6 цифр');
      }
      final random = Random.secure();
      final salt = List.generate(32, (_) => random.nextInt(256));
      final hash = await _derive(pin, salt, iterations);
      await write(
        'pin_v1',
        jsonEncode({
          'version': 1,
          'iterations': iterations,
          'salt': base64Encode(salt),
          'hash': base64Encode(hash),
        }),
      );
      await resetFailures();
    } finally {
      _busy = false;
    }
  }

  Future<bool> verify(String pin) async {
    if (_busy) throw StateError('Проверка уже выполняется');
    _busy = true;
    try {
      if (await delay() > Duration.zero) return false;
      final encoded = await read('pin_v1');
      if (encoded == null) return false;
      final config = jsonDecode(encoded) as Map<String, dynamic>;
      if (config['version'] != 1 || config['iterations'] != iterations) {
        throw StateError('Неизвестный формат PIN');
      }
      final salt = base64Decode(config['salt'] as String);
      final expected = base64Decode(config['hash'] as String);
      if (salt.length != 32 || expected.length != 32) {
        throw StateError('Повреждена запись PIN');
      }
      final actual = await _derive(pin, salt, iterations);
      var diff = actual.length ^ expected.length;
      for (var i = 0; i < expected.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      final valid = RegExp(r'^\d{6}$').hasMatch(pin) && diff == 0;
      if (valid) {
        await resetFailures();
      } else {
        final old = jsonDecode(
          await read('pin_failures_v1') ?? '{}',
        ) as Map<String, dynamic>;
        final failures = ((old['count'] as int?) ?? 0) + 1;
        final seconds = failures < 5
            ? 0
            : min(3600, 30 * (1 << min(7, failures - 5)));
        await write(
          'pin_failures_v1',
          jsonEncode({
            'count': failures,
            'until': now()
                .add(Duration(seconds: seconds))
                .millisecondsSinceEpoch,
          }),
        );
      }
      return valid;
    } finally {
      _busy = false;
    }
  }

  Future<void> resetFailures() =>
      write('pin_failures_v1', '{"count":0,"until":0}');
}
