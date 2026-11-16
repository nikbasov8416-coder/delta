import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'pin_policy.dart';

/// Хранилище передаётся функциями: доменный код не зависит от платформы.
class PinService {
  PinService({
    required this.read,
    required this.write,
    DateTime Function()? now,
    int targetIterations = PinPolicy.iterations,
  }) : now = now ?? DateTime.now,
       targetIterations = targetIterations {
    if (targetIterations < PinPolicy.minimumAcceptedIterations ||
        targetIterations > PinPolicy.maximumAcceptedIterations) {
      throw ArgumentError('Недопустимое число итераций PIN');
    }
  }
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) write;
  final DateTime Function() now;
  final int targetIterations;
  bool _busy = false;

  Future<bool> get configured async => await _record() != null;

  static const _slots = ['pin_v1', 'pin_v2'];
  bool migrationPending = false;

  ({String key, String encoded, int count, List<int> salt, List<int> hash})?
  _parse(String key, String? encoded) {
    if (encoded == null) return null;
    try {
      final config = jsonDecode(encoded) as Map<String, dynamic>;
      final count = config['iterations'];
      if (config['version'] != 1 ||
          count is! int ||
          count < PinPolicy.minimumAcceptedIterations ||
          count > PinPolicy.maximumAcceptedIterations) {
        return null;
      }
      final salt = base64Decode(config['salt'] as String),
          hash = base64Decode(config['hash'] as String);
      if (salt.length != 32 || hash.length != 32) return null;
      return (key: key, encoded: encoded, count: count, salt: salt, hash: hash);
    } catch (_) {
      return null;
    }
  }

  Future<
    ({String key, String encoded, int count, List<int> salt, List<int> hash})?
  >
  _record() async {
    final records =
        <
          ({
            String key,
            String encoded,
            int count,
            List<int> salt,
            List<int> hash,
          })
        >[];
    var damaged = false;
    for (final key in _slots) {
      try {
        final encoded = await read(key);
        final record = _parse(key, encoded);
        if (record != null) {
          records.add(record);
        } else if (encoded != null) {
          damaged = true;
        }
      } catch (_) {
        damaged = true;
      }
    }
    if (records.isEmpty) {
      if (damaged) {
        throw StateError('Защищённая запись PIN недоступна или повреждена');
      }
      return null;
    }
    return records.firstWhere(
      (record) => record.count == targetIterations,
      orElse: () => records.first,
    );
  }

  Future<void> _upgradeOrRepair(
    String pin,
    ({String key, String encoded, int count, List<int> salt, List<int> hash})
    current,
  ) async {
    final other = current.key == 'pin_v1' ? 'pin_v2' : 'pin_v1';
    if (current.count == targetIterations) {
      // Восстановление второй копии не затрагивает уже проверенную запись.
      try {
        if (await read(other) != current.encoded) {
          await write(other, current.encoded);
          if (await read(other) != current.encoded) migrationPending = true;
        }
      } catch (_) {
        migrationPending = true;
      }
      return;
    }
    final random = Random.secure();
    final salt = List.generate(32, (_) => random.nextInt(256));
    final hash = await _derive(pin, salt, targetIterations);
    final replacement = jsonEncode({
      'version': 1,
      'iterations': targetIterations,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
    });
    try {
      // Сначала другой слот. Частичная запись не уничтожает проверенный хеш.
      await write(other, replacement);
      if (await read(other) != replacement) {
        throw StateError('Не подтверждена запись нового хеша');
      }
      // Новая запись уже проверена чтением: можно обновить старую копию.
      try {
        await write(current.key, replacement);
        if (await read(current.key) != replacement) migrationPending = true;
      } catch (_) {
        migrationPending = true;
      }
    } catch (_) {
      migrationPending = true;
    }
    // Не блокируем вход: исходный PIN уже проверен, как минимум один слот
    // сохранён. Повтор обновления/ремонта будет при следующем PIN-входе.
  }

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
      final hash = await _derive(pin, salt, targetIterations);
      final encoded = jsonEncode({
        'version': 1,
        'iterations': targetIterations,
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      });
      await write('pin_v1', encoded);
      if (await read('pin_v1') != encoded) {
        throw StateError('Не удалось подтвердить сохранение PIN');
      }
      // До допуска в приложение проверяем сохранение, затем создаём резервную
      // копию того же хеша без повторного вычисления PBKDF2.
      await _upgradeOrRepair(pin, _parse('pin_v1', encoded)!);
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
      migrationPending = false;
      final record = await _record();
      if (record == null) return false;
      final expected = record.hash;
      final actual = await _derive(pin, record.salt, record.count);
      var diff = actual.length ^ expected.length;
      for (var i = 0; i < expected.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      final valid = RegExp(r'^\d{6}$').hasMatch(pin) && diff == 0;
      if (valid) {
        await _upgradeOrRepair(pin, record);
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
